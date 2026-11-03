class_name ControlServer
extends Node
## One-port LAN server for the phone controller: GET / serves the phone page and a
## `Upgrade: websocket` request on /ws becomes the single controller socket.
##
## Godot's `WebSocketPeer.accept_stream()` only takes an unread `StreamPeerTCP` and parses the
## HTTP handshake itself, so it cannot share a port with our own HTTP routing. The server
## therefore does the RFC 6455 handshake and framing here (small text frames only).
## It never touches input: whoever owns it connects `message_received` to the mapper.

signal controller_connected
signal controller_disconnected
signal message_received(msg: Dictionary)
signal controller_rejected

const PAGE_PATH := "res://assets/web/mando.html"
const WS_PATH := "/ws"
const WS_GUID := "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
const SILENCE_TIMEOUT_MS := 5000
const MAX_MESSAGES_PER_SECOND := 60
const MAX_HEADER_BYTES := 8192
const MAX_FRAME_PAYLOAD := 4096
const MAX_PENDING := 8
const REQUEST_TIMEOUT_MS := 5000
## Time a finished connection keeps draining before it is closed, so the last response is not
## lost to a reset caused by unread incoming bytes.
const LINGER_MS := 1000
## The busy reply is spread out: the text frame a moment after the 101 handshake and the close
## frame a moment later. Godot's own WebSocketPeer client drops a text frame that arrives in the
## same read as the close frame; browsers do not need it but it costs nothing.
const BUSY_STEP_MS := 150

const OPCODE_CONTINUATION := 0x0
const OPCODE_TEXT := 0x1
const OPCODE_BINARY := 0x2
const OPCODE_CLOSE := 0x8
const OPCODE_PING := 0x9
const OPCODE_PONG := 0xA

const CLOSE_NORMAL := 1000
const CLOSE_GOING_AWAY := 1001
const CLOSE_PROTOCOL_ERROR := 1002
const CLOSE_UNSUPPORTED := 1003
const CLOSE_TOO_BIG := 1009

var _server: TCPServer = null
var _port: int = 8080
## Connections still sending their HTTP request: {"peer", "buffer", "since"}.
var _pending: Array[Dictionary] = []
## Connections about to close: {"peer", "chunks" ([send_at_ms, bytes] still to send), "until"}.
var _closing: Array[Dictionary] = []
var _controller: StreamPeerTCP = null
var _controller_buffer := PackedByteArray()
var _last_message_ms: int = 0
var _rate_state: Dictionary = {}


func _init() -> void:
	# The phone must keep its socket while the game is paused (the panel lives in the menus).
	process_mode = Node.PROCESS_MODE_ALWAYS


func _exit_tree() -> void:
	stop()


func _process(_delta: float) -> void:
	if _server != null:
		_poll(Time.get_ticks_msec())


## Opens the port. Returns ERR_UNAVAILABLE in headless runs and with `--no-save` (tests).
func start(port: int = 8080) -> Error:
	if not can_open_port():
		return ERR_UNAVAILABLE
	return _listen(port)


func stop() -> void:
	if _controller != null:
		_drop_controller(CLOSE_GOING_AWAY)
	for entry: Dictionary in _pending:
		(entry["peer"] as StreamPeerTCP).disconnect_from_host()
	_pending.clear()
	for entry: Dictionary in _closing:
		(entry["peer"] as StreamPeerTCP).disconnect_from_host()
	_closing.clear()
	if _server != null:
		_server.stop()
		_server = null


func is_running() -> bool:
	return _server != null and _server.is_listening()


func has_controller() -> bool:
	return _controller != null


## One `http://<ip>:<port>/` per private LAN IPv4 address of this machine.
func get_urls() -> PackedStringArray:
	var urls := PackedStringArray()
	for address in lan_addresses():
		urls.append("http://%s:%d/" % [address, _port])
	return urls


static func can_open_port() -> bool:
	return DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().has("--no-save")


## Private IPv4 addresses of this machine, 192.168.x first, then 10.x, then 172.16-31.x
## (virtual adapters such as WSL usually sit in 172.x, so they go last).
static func lan_addresses() -> PackedStringArray:
	return filter_private_ipv4(IP.get_local_addresses())


static func filter_private_ipv4(addresses: PackedStringArray) -> PackedStringArray:
	var groups: Array[PackedStringArray] = [PackedStringArray(), PackedStringArray(), PackedStringArray()]
	for address in addresses:
		var octets := _ipv4_octets(address)
		if octets.is_empty():
			continue
		if octets[0] == 192 and octets[1] == 168:
			groups[0].append(address)
		elif octets[0] == 10:
			groups[1].append(address)
		elif octets[0] == 172 and octets[1] >= 16 and octets[1] <= 31:
			groups[2].append(address)
	var result := PackedStringArray()
	for group in groups:
		result.append_array(group)
	return result


static func is_private_ipv4(address: String) -> bool:
	return not filter_private_ipv4(PackedStringArray([address])).is_empty()


static func _ipv4_octets(address: String) -> PackedInt32Array:
	var parts := address.split(".")
	if parts.size() != 4:
		return PackedInt32Array()
	var octets := PackedInt32Array()
	for part in parts:
		if part.is_empty() or not part.is_valid_int():
			return PackedInt32Array()
		var value := part.to_int()
		if value < 0 or value > 255:
			return PackedInt32Array()
		octets.append(value)
	return octets


# --- HTTP parsing (pure) ---

## "GET /ws HTTP/1.1" -> {"method", "path", "version"}; {} when malformed.
static func parse_request_line(line: String) -> Dictionary:
	var parts := line.strip_edges().split(" ", false)
	if parts.size() != 3 or not parts[2].begins_with("HTTP/") or not parts[1].begins_with("/"):
		return {}
	return {"method": parts[0], "path": parts[1], "version": parts[2]}


## Header lines -> Dictionary with lower-case names and stripped values.
static func parse_headers(lines: PackedStringArray) -> Dictionary:
	var headers := {}
	for line in lines:
		var colon := line.find(":")
		if colon <= 0:
			continue
		headers[line.substr(0, colon).strip_edges().to_lower()] = line.substr(colon + 1).strip_edges()
	return headers


## Case-insensitive header lookup; "" when missing.
static func header_value(headers: Dictionary, name: String) -> String:
	var key := name.to_lower()
	if headers.has(key):
		return str(headers[key])
	for header: String in headers:
		if header.to_lower() == key:
			return str(headers[header])
	return ""


## Full request head (without the blank line) -> request line fields plus "headers"; {} if malformed.
static func parse_request(head: String) -> Dictionary:
	var lines := head.split("\r\n")
	if lines.is_empty():
		return {}
	var request := parse_request_line(lines[0])
	if request.is_empty():
		return {}
	request["headers"] = parse_headers(lines.slice(1))
	return request


## Path without query string or fragment.
static func request_path(request: Dictionary) -> String:
	var path := str(request.get("path", ""))
	for separator in ["?", "#"]:
		var index := path.find(separator)
		if index >= 0:
			path = path.substr(0, index)
	return path


static func is_websocket_upgrade(request: Dictionary) -> bool:
	if str(request.get("method", "")) != "GET" or request_path(request) != WS_PATH:
		return false
	var headers: Dictionary = request.get("headers", {})
	if header_value(headers, "upgrade").to_lower().strip_edges() != "websocket":
		return false
	if not _has_token(header_value(headers, "connection"), "upgrade"):
		return false
	return not header_value(headers, "sec-websocket-key").is_empty()


static func _has_token(value: String, token: String) -> bool:
	for part in value.split(","):
		if part.strip_edges().to_lower() == token:
			return true
	return false


## Index right after the "\r\n\r\n" that ends the request head, or -1.
static func find_header_end(buffer: PackedByteArray) -> int:
	for i in range(3, buffer.size()):
		if buffer[i] == 10 and buffer[i - 1] == 13 and buffer[i - 2] == 10 and buffer[i - 3] == 13:
			return i + 1
	return -1


static func websocket_accept_key(key: String) -> String:
	var hashing := HashingContext.new()
	hashing.start(HashingContext.HASH_SHA1)
	hashing.update((key.strip_edges() + WS_GUID).to_utf8_buffer())
	return Marshalls.raw_to_base64(hashing.finish())


static func http_response(status: String, content_type: String, body: PackedByteArray) -> PackedByteArray:
	var head := "HTTP/1.1 %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nCache-Control: no-store\r\nConnection: close\r\n\r\n" % [status, content_type, body.size()]
	var bytes := head.to_utf8_buffer()
	bytes.append_array(body)
	return bytes


static func handshake_response(key: String) -> PackedByteArray:
	return ("HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: %s\r\n\r\n" % websocket_accept_key(key)).to_utf8_buffer()


# --- WebSocket framing (pure) ---

## Decodes one client frame from the start of `buffer`.
## {} = need more bytes; {"error": close_code} = invalid; else {"fin", "opcode", "payload", "size"}.
static func decode_frame(buffer: PackedByteArray, max_payload: int = MAX_FRAME_PAYLOAD) -> Dictionary:
	if buffer.size() < 2:
		return {}
	var fin := (buffer[0] & 0x80) != 0
	var opcode := buffer[0] & 0x0F
	var length := buffer[1] & 0x7F
	if (buffer[0] & 0x70) != 0 or (buffer[1] & 0x80) == 0:
		return {"error": CLOSE_PROTOCOL_ERROR}  # Reserved bits set, or an unmasked client frame.
	if opcode >= OPCODE_CLOSE and (not fin or length > 125):
		return {"error": CLOSE_PROTOCOL_ERROR}
	var offset := 2
	if length == 126:
		if buffer.size() < 4:
			return {}
		length = (buffer[2] << 8) | buffer[3]
		offset = 4
	elif length == 127:
		return {"error": CLOSE_TOO_BIG}  # 64-bit lengths are far beyond any controller message.
	if length > max_payload:
		return {"error": CLOSE_TOO_BIG}
	if buffer.size() < offset + 4 + length:
		return {}
	var mask := buffer.slice(offset, offset + 4)
	offset += 4
	var payload := buffer.slice(offset, offset + length)
	for i in length:
		payload[i] = payload[i] ^ mask[i % 4]
	return {"fin": fin, "opcode": opcode, "payload": payload, "size": offset + length}


## Unmasked server frame (servers never mask).
static func encode_frame(opcode: int, payload: PackedByteArray) -> PackedByteArray:
	var frame := PackedByteArray([0x80 | (opcode & 0x0F)])
	var length := payload.size()
	if length < 126:
		frame.append(length)
	elif length < 65536:
		frame.append_array(PackedByteArray([126, (length >> 8) & 0xFF, length & 0xFF]))
	else:
		frame.append(127)
		for shift in [56, 48, 40, 32, 24, 16, 8, 0]:
			frame.append((length >> shift) & 0xFF)
	frame.append_array(payload)
	return frame


static func encode_text(text: String) -> PackedByteArray:
	return encode_frame(OPCODE_TEXT, text.to_utf8_buffer())


static func encode_close(code: int) -> PackedByteArray:
	return encode_frame(OPCODE_CLOSE, PackedByteArray([(code >> 8) & 0xFF, code & 0xFF]))


## JSON text -> Dictionary, or null for anything else (invalid JSON, arrays, numbers...).
## Uses a JSON instance instead of `JSON.parse_string`, which in 4.7 prints an engine ERROR
## for every malformed message and would let any LAN client flood the console.
static func parse_message(text: String) -> Variant:
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	return json.data if json.data is Dictionary else null


# --- Limits (pure) ---

## Fixed one-second window: true while fewer than `limit` messages were accepted in it.
static func rate_allow(state: Dictionary, now_ms: int, limit: int = MAX_MESSAGES_PER_SECOND) -> bool:
	if not state.has("window_start") or now_ms - int(state["window_start"]) >= 1000:
		state["window_start"] = now_ms
		state["count"] = 0
	if int(state["count"]) >= limit:
		return false
	state["count"] = int(state["count"]) + 1
	return true


static func is_silent(last_message_ms: int, now_ms: int) -> bool:
	return now_ms - last_message_ms >= SILENCE_TIMEOUT_MS


# --- Networking ---

func _listen(port: int) -> Error:
	stop()
	_port = port
	_server = TCPServer.new()
	var error := _server.listen(port)
	if error != OK:
		_server = null
	return error


func _poll(now_ms: int) -> void:
	while _server.is_connection_available():
		var peer := _server.take_connection()
		if _pending.size() >= MAX_PENDING:
			peer.disconnect_from_host()
			continue
		_pending.append({"peer": peer, "buffer": PackedByteArray(), "since": now_ms})
	_poll_pending(now_ms)
	_poll_controller(now_ms)
	_poll_closing(now_ms)


func _poll_pending(now_ms: int) -> void:
	for entry: Dictionary in _pending.duplicate():
		var peer: StreamPeerTCP = entry["peer"]
		peer.poll()
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			_pending.erase(entry)
			continue
		var buffer: PackedByteArray = entry["buffer"]
		buffer.append_array(_read_available(peer))
		entry["buffer"] = buffer
		var end := find_header_end(buffer)
		if end < 0:
			if buffer.size() > MAX_HEADER_BYTES or now_ms - int(entry["since"]) > REQUEST_TIMEOUT_MS:
				_pending.erase(entry)
				_finish(peer, http_response("400 Bad Request", "text/plain", "Bad Request".to_utf8_buffer()), now_ms)
			continue
		_pending.erase(entry)
		_handle_request(peer, parse_request(buffer.slice(0, end - 4).get_string_from_utf8()), buffer.slice(end), now_ms)


func _handle_request(peer: StreamPeerTCP, request: Dictionary, rest: PackedByteArray, now_ms: int) -> void:
	if request.is_empty():
		_finish(peer, http_response("400 Bad Request", "text/plain", "Bad Request".to_utf8_buffer()), now_ms)
	elif is_websocket_upgrade(request):
		_accept_websocket(peer, header_value(request["headers"], "sec-websocket-key"), rest, now_ms)
	elif request["method"] != "GET":
		_finish(peer, http_response("405 Method Not Allowed", "text/plain", "Method Not Allowed".to_utf8_buffer()), now_ms)
	elif request_path(request) == "/" and FileAccess.file_exists(PAGE_PATH):
		_finish(peer, http_response("200 OK", "text/html; charset=utf-8", FileAccess.get_file_as_bytes(PAGE_PATH)), now_ms)
	else:
		_finish(peer, http_response("404 Not Found", "text/plain", "Not Found".to_utf8_buffer()), now_ms)


func _accept_websocket(peer: StreamPeerTCP, key: String, rest: PackedByteArray, now_ms: int) -> void:
	peer.put_data(handshake_response(key))
	if _controller != null:
		# D2: one controller at a time.
		# Close code 1000: Godot's client rejects 1013 (try again later) as a protocol error.
		_finish(peer, PackedByteArray(), now_ms, [
			[now_ms + BUSY_STEP_MS, encode_text(JSON.stringify({"type": "busy"}))],
			[now_ms + 2 * BUSY_STEP_MS, encode_close(CLOSE_NORMAL)],
		])
		controller_rejected.emit()
		return
	peer.set_no_delay(true)
	_controller = peer
	_controller_buffer = rest
	_last_message_ms = now_ms
	_rate_state = {}
	controller_connected.emit()


func _poll_controller(now_ms: int) -> void:
	if _controller == null:
		return
	_controller.poll()
	if _controller.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		_drop_controller(-1)
		return
	_controller_buffer.append_array(_read_available(_controller))
	while _controller != null:
		var frame := decode_frame(_controller_buffer)
		if frame.is_empty():
			break
		if frame.has("error"):
			_drop_controller(int(frame["error"]))
			return
		_controller_buffer = _controller_buffer.slice(int(frame["size"]))
		_last_message_ms = now_ms
		_handle_frame(frame, now_ms)
	if _controller != null and is_silent(_last_message_ms, now_ms):
		_drop_controller(CLOSE_GOING_AWAY)


func _handle_frame(frame: Dictionary, now_ms: int) -> void:
	var opcode: int = frame["opcode"]
	var payload: PackedByteArray = frame["payload"]
	match opcode:
		OPCODE_TEXT:
			if not frame["fin"]:
				_drop_controller(CLOSE_UNSUPPORTED)  # The phone page never fragments its tiny messages.
				return
			if not rate_allow(_rate_state, now_ms):
				return
			var msg: Variant = parse_message(payload.get_string_from_utf8())
			if msg != null:
				message_received.emit(msg)
		OPCODE_CLOSE:
			_drop_controller(CLOSE_NORMAL)
		OPCODE_PING:
			_controller.put_data(encode_frame(OPCODE_PONG, payload))
		OPCODE_CONTINUATION:
			_drop_controller(CLOSE_UNSUPPORTED)
		_:
			pass  # Binary and pong frames only count as signs of life.


## Closes the controller socket (sending a close frame unless `code` < 0) and tells listeners.
func _drop_controller(code: int) -> void:
	var peer := _controller
	_controller = null
	_controller_buffer = PackedByteArray()
	if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and code >= 0:
		_finish(peer, encode_close(code), Time.get_ticks_msec())
	else:
		peer.disconnect_from_host()
	controller_disconnected.emit()


## Sends `bytes` now and each later chunk ([send_at_ms, bytes]) at its time, then keeps
## draining the peer for LINGER_MS before closing it.
func _finish(peer: StreamPeerTCP, bytes: PackedByteArray, now_ms: int, later: Array = []) -> void:
	if not bytes.is_empty() and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		peer.put_data(bytes)
	var last_ms := now_ms
	for chunk: Array in later:
		last_ms = maxi(last_ms, int(chunk[0]))
	_closing.append({"peer": peer, "chunks": later.duplicate(), "until": last_ms + LINGER_MS})


func _poll_closing(now_ms: int) -> void:
	for entry: Dictionary in _closing.duplicate():
		var peer: StreamPeerTCP = entry["peer"]
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			_read_available(peer)  # Drain so closing does not reset the connection.
			var chunks: Array = entry["chunks"]
			while not chunks.is_empty() and now_ms >= int(chunks[0][0]):
				peer.put_data(chunks.pop_front()[1])
			if now_ms < int(entry["until"]):
				continue
		peer.disconnect_from_host()
		_closing.erase(entry)


func _read_available(peer: StreamPeerTCP) -> PackedByteArray:
	var available := peer.get_available_bytes()
	if available <= 0:
		return PackedByteArray()
	var result: Array = peer.get_partial_data(available)
	if result[0] != OK:
		return PackedByteArray()
	return result[1]
