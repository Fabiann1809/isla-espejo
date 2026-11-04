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
## Every frame (ping, pong, binary included) counts here; above it the controller is closed.
const MAX_FRAMES_PER_SECOND := 120
## Bytes read from the controller per poll, so a flood cannot stall a frame.
const MAX_READ_PER_POLL := 8192
## Unsent bytes allowed for the controller before it counts as not reading and is cut.
const MAX_CONTROLLER_BACKLOG := 4096
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
## Lower-case pieces of interface names that mark a virtual adapter (its address goes last).
const VIRTUAL_INTERFACE_MARKERS: Array[String] = [
	"virtual", "vmware", "vbox", "hyper-v", "wsl", "docker", "loopback", "tap", "vethernet",
	"virbr", "vmnet", "br-", "bridge",
]

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
const CLOSE_POLICY := 1008
const CLOSE_TOO_BIG := 1009

var _server: TCPServer = null
var _port: int = 8080
## Connections still sending their HTTP request: {"peer", "buffer", "since"}.
var _pending: Array[Dictionary] = []
## Connections about to close: {"peer", "chunks" ([send_at_ms, bytes] still to send), "until", "deadline"}.
var _closing: Array[Dictionary] = []
var _controller: StreamPeerTCP = null
var _controller_buffer := PackedByteArray()
var _last_message_ms: int = 0
var _rate_state: Dictionary = {}
var _frame_state: Dictionary = {}
## Bytes accepted by `_send` that the socket could not take yet, per peer.
var _out_queues: Dictionary = {}


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
		_close_peer(entry["peer"])
	_pending.clear()
	for entry: Dictionary in _closing:
		_close_peer(entry["peer"])
	_closing.clear()
	_out_queues.clear()
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


## Private IPv4 addresses of this machine, those of real adapters first (see
## `addresses_from_interfaces`), so the QR, which takes the first one, points at the Wi-Fi.
static func lan_addresses() -> PackedStringArray:
	var interfaces: Array = IP.get_local_interfaces()
	if interfaces.is_empty():
		return filter_private_ipv4(IP.get_local_addresses())
	return addresses_from_interfaces(interfaces)


## Pure part of `lan_addresses`. `interfaces` has the shape of `IP.get_local_interfaces()`:
## [{"name", "friendly", "index", "addresses"}]. Private IPv4 addresses of real interfaces come
## first, then those of virtual ones (VirtualBox, VMware, Hyper-V, WSL, Docker, the Windows
## hosted network...), so a virtual address is only used when nothing else exists.
static func addresses_from_interfaces(interfaces: Array) -> PackedStringArray:
	var real := PackedStringArray()
	var virtual := PackedStringArray()
	for iface: Variant in interfaces:
		if not iface is Dictionary:
			continue
		var is_virtual := is_virtual_interface(iface)
		var addresses: Variant = iface.get("addresses", [])
		if not (addresses is Array or addresses is PackedStringArray):
			continue
		for address: Variant in addresses:
			if not address is String:
				continue
			# Packed arrays are copied on assignment, so append to each one by name.
			if is_virtual:
				virtual.append(address)
			else:
				real.append(address)
	var result := PackedStringArray()
	for address in filter_private_ipv4(real) + filter_private_ipv4(virtual):
		if not result.has(address):
			result.append(address)
	return result


## True for adapters that are not the machine's real network. On Windows `name` is a GUID, so
## the `friendly` name is checked too; Windows also names its hidden virtual adapters (Wi-Fi
## Direct, hosted network on 192.168.137.1) "Local Area Connection* N" with an asterisk.
static func is_virtual_interface(iface: Dictionary) -> bool:
	var text := ("%s %s" % [iface.get("name", ""), iface.get("friendly", "")]).to_lower()
	if text.contains("*"):
		return true
	for marker in VIRTUAL_INTERFACE_MARKERS:
		if text.contains(marker):
			return true
	return false


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

## Decodes one client frame starting at byte `start` of `buffer` (no copy of the buffer).
## {} = need more bytes; {"error": close_code} = invalid;
## else {"fin", "opcode", "payload", "size"} where size is the frame's length in bytes.
static func decode_frame(buffer: PackedByteArray, max_payload: int = MAX_FRAME_PAYLOAD, start: int = 0) -> Dictionary:
	var available := buffer.size() - start
	if available < 2:
		return {}
	var b0 := buffer[start]
	var b1 := buffer[start + 1]
	var fin := (b0 & 0x80) != 0
	var opcode := b0 & 0x0F
	var length := b1 & 0x7F
	if (b0 & 0x70) != 0 or (b1 & 0x80) == 0:
		return {"error": CLOSE_PROTOCOL_ERROR}  # Reserved bits set, or an unmasked client frame.
	if opcode >= OPCODE_CLOSE and (not fin or length > 125):
		return {"error": CLOSE_PROTOCOL_ERROR}
	var header := 2
	if length == 126:
		if available < 4:
			return {}
		length = (buffer[start + 2] << 8) | buffer[start + 3]
		header = 4
	elif length == 127:
		return {"error": CLOSE_TOO_BIG}  # 64-bit lengths are far beyond any controller message.
	if length > max_payload:
		return {"error": CLOSE_TOO_BIG}
	if available < header + 4 + length:
		return {}
	var mask_at := start + header
	var payload := buffer.slice(mask_at + 4, mask_at + 4 + length)
	for i in length:
		payload[i] = payload[i] ^ buffer[mask_at + i % 4]
	return {"fin": fin, "opcode": opcode, "payload": payload, "size": header + 4 + length}


## The controller protocol and the request head are plain ASCII; anything else is rejected
## before decoding (UTF-8 decoding prints one engine error per bad byte).
static func is_ascii(bytes: PackedByteArray) -> bool:
	for byte in bytes:
		if byte >= 0x80:
			return false
	return true


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


## Text frame {"type":"pong","t":<same t>} for a {"type":"ping","t":<number>} message; empty
## for anything else (a ping without a numeric, finite `t` gets no reply).
static func pong_reply(msg: Dictionary) -> PackedByteArray:
	if msg.get("type") != "ping":
		return PackedByteArray()
	var t: Variant = msg.get("t")
	if not (t is float or t is int):
		return PackedByteArray()
	var value: float = float(t)
	if is_nan(value) or is_inf(value):
		return PackedByteArray()
	# JSON numbers arrive as floats; whole ones (client ms) go back without a ".0".
	var echoed: Variant = int(value) if value == floorf(value) and absf(value) < 9007199254740992.0 else value
	return encode_text(JSON.stringify({"type": "pong", "t": echoed}, "", false, true))


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
			_close_peer(peer)
			continue
		var buffer: PackedByteArray = entry["buffer"]
		buffer.append_array(_read_available(peer, MAX_HEADER_BYTES + 1 - buffer.size()))
		entry["buffer"] = buffer
		var end := find_header_end(buffer)
		if end < 0:
			if buffer.size() > MAX_HEADER_BYTES or now_ms - int(entry["since"]) > REQUEST_TIMEOUT_MS:
				_pending.erase(entry)
				_finish(peer, _bad_request(), now_ms)
			continue
		_pending.erase(entry)
		var head := buffer.slice(0, end - 4)
		if not is_ascii(head):
			_finish(peer, _bad_request(), now_ms)
			continue
		_handle_request(peer, parse_request(head.get_string_from_ascii()), buffer.slice(end), now_ms)


func _handle_request(peer: StreamPeerTCP, request: Dictionary, rest: PackedByteArray, now_ms: int) -> void:
	if request.is_empty():
		_finish(peer, _bad_request(), now_ms)
	elif is_websocket_upgrade(request):
		_accept_websocket(peer, header_value(request["headers"], "sec-websocket-key"), rest, now_ms)
	elif request["method"] != "GET":
		_finish(peer, http_response("405 Method Not Allowed", "text/plain", "Method Not Allowed".to_utf8_buffer()), now_ms)
	elif request_path(request) == "/" and FileAccess.file_exists(PAGE_PATH):
		_finish(peer, http_response("200 OK", "text/html; charset=utf-8", FileAccess.get_file_as_bytes(PAGE_PATH)), now_ms)
	else:
		_finish(peer, http_response("404 Not Found", "text/plain", "Not Found".to_utf8_buffer()), now_ms)


static func _bad_request() -> PackedByteArray:
	return http_response("400 Bad Request", "text/plain", "Bad Request".to_utf8_buffer())


func _accept_websocket(peer: StreamPeerTCP, key: String, rest: PackedByteArray, now_ms: int) -> void:
	if _controller != null:
		# D2: one controller at a time.
		# Close code 1000: Godot's client rejects 1013 (try again later) as a protocol error.
		_finish(peer, handshake_response(key), now_ms, [
			[now_ms + BUSY_STEP_MS, encode_text(JSON.stringify({"type": "busy"}))],
			[now_ms + 2 * BUSY_STEP_MS, encode_close(CLOSE_NORMAL)],
		])
		controller_rejected.emit()
		return
	if not _send(peer, handshake_response(key)):
		_close_peer(peer)
		return
	peer.set_no_delay(true)
	_controller = peer
	_controller_buffer = rest
	_last_message_ms = now_ms
	_rate_state = {}
	_frame_state = {}
	controller_connected.emit()


func _poll_controller(now_ms: int) -> void:
	if _controller == null:
		return
	_controller.poll()
	if _controller.get_status() != StreamPeerTCP.STATUS_CONNECTED or not _flush(_controller):
		_drop_controller(-1)
		return
	_controller_buffer.append_array(_read_available(_controller, MAX_READ_PER_POLL))
	var offset := 0
	while _controller != null:
		var frame := decode_frame(_controller_buffer, MAX_FRAME_PAYLOAD, offset)
		if frame.is_empty():
			break
		if frame.has("error"):
			_drop_controller(int(frame["error"]))
			return
		offset += int(frame["size"])
		_last_message_ms = now_ms
		if not rate_allow(_frame_state, now_ms, MAX_FRAMES_PER_SECOND):
			_drop_controller(CLOSE_POLICY)
			return
		_handle_frame(frame, now_ms)
	if _controller == null:
		return
	if offset > 0:
		_controller_buffer = _controller_buffer.slice(offset)
	if is_silent(_last_message_ms, now_ms):
		_drop_controller(CLOSE_GOING_AWAY)


func _handle_frame(frame: Dictionary, now_ms: int) -> void:
	var opcode: int = frame["opcode"]
	var payload: PackedByteArray = frame["payload"]
	match opcode:
		OPCODE_TEXT:
			if not frame["fin"]:
				_drop_controller(CLOSE_UNSUPPORTED)  # The phone page never fragments its tiny messages.
				return
			if not rate_allow(_rate_state, now_ms) or not is_ascii(payload):
				return
			var msg: Variant = parse_message(payload.get_string_from_ascii())
			if msg != null:
				message_received.emit(msg)
				# The page measures its round-trip time with the echoed `t`.
				var pong := pong_reply(msg)
				if not pong.is_empty() and _controller != null:
					_send_to_controller(pong)
		OPCODE_CLOSE:
			_drop_controller(CLOSE_NORMAL)
		OPCODE_PING:
			_send_to_controller(encode_frame(OPCODE_PONG, payload))
		OPCODE_CONTINUATION:
			_drop_controller(CLOSE_UNSUPPORTED)
		_:
			pass  # Binary and pong frames only count as signs of life.


## A controller that stops reading is cut without a close frame (it would not read it either).
func _send_to_controller(bytes: PackedByteArray) -> void:
	if not _send(_controller, bytes) or _queued_bytes(_controller) > MAX_CONTROLLER_BACKLOG:
		_drop_controller(-1)


## Closes the controller socket (sending a close frame unless `code` < 0) and tells listeners.
func _drop_controller(code: int) -> void:
	var peer := _controller
	_controller = null
	_controller_buffer = PackedByteArray()
	if code >= 0 and peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
		_finish(peer, encode_close(code), Time.get_ticks_msec())
	else:
		_close_peer(peer)
	controller_disconnected.emit()


## Sends `bytes` now and each later chunk ([send_at_ms, bytes]) at its time, then keeps
## draining the peer for LINGER_MS (and until everything queued went out) before closing it.
func _finish(peer: StreamPeerTCP, bytes: PackedByteArray, now_ms: int, later: Array = []) -> void:
	if not _send(peer, bytes):
		_close_peer(peer)
		return
	var last_ms := now_ms
	for chunk: Array in later:
		last_ms = maxi(last_ms, int(chunk[0]))
	_closing.append({"peer": peer, "chunks": later.duplicate(), "until": last_ms + LINGER_MS,
		"deadline": last_ms + LINGER_MS + REQUEST_TIMEOUT_MS})


func _poll_closing(now_ms: int) -> void:
	for entry: Dictionary in _closing.duplicate():
		var peer: StreamPeerTCP = entry["peer"]
		peer.poll()
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED and now_ms < int(entry["deadline"]):
			_read_available(peer, MAX_READ_PER_POLL)  # Drain so closing does not reset the connection.
			var chunks: Array = entry["chunks"]
			var sent := _flush(peer)
			while sent and not chunks.is_empty() and now_ms >= int(chunks[0][0]):
				sent = _send(peer, chunks.pop_front()[1])
			if sent and (now_ms < int(entry["until"]) or not chunks.is_empty() or _queued_bytes(peer) > 0):
				continue
		_close_peer(peer)
		_closing.erase(entry)


## Non-blocking send: queues `bytes` behind anything still unsent for this peer and writes what
## the socket takes now (`put_data` would block the game while a client is not reading).
## False on a socket error.
func _send(peer: StreamPeerTCP, bytes: PackedByteArray) -> bool:
	if not bytes.is_empty():
		var queue: PackedByteArray = _out_queues.get(peer, PackedByteArray())
		_out_queues.erase(peer)  # Drop the dictionary's reference so the append does not copy.
		queue.append_array(bytes)
		_out_queues[peer] = queue
	return _flush(peer)


## Writes as much of the peer's queue as the socket accepts now. False on a socket error.
func _flush(peer: StreamPeerTCP) -> bool:
	if not _out_queues.has(peer):
		return true
	var queue: PackedByteArray = _out_queues[peer]
	var result: Array = peer.put_partial_data(queue)
	if result[0] != OK:
		_out_queues.erase(peer)
		return false
	var sent: int = result[1]
	if sent >= queue.size():
		_out_queues.erase(peer)
	elif sent > 0:
		_out_queues[peer] = queue.slice(sent)
	return true


func _queued_bytes(peer: StreamPeerTCP) -> int:
	if not _out_queues.has(peer):
		return 0
	return (_out_queues[peer] as PackedByteArray).size()


func _close_peer(peer: StreamPeerTCP) -> void:
	_out_queues.erase(peer)
	peer.disconnect_from_host()


func _read_available(peer: StreamPeerTCP, max_bytes: int) -> PackedByteArray:
	var count := mini(peer.get_available_bytes(), max_bytes)
	if count <= 0:
		return PackedByteArray()
	var result: Array = peer.get_partial_data(count)
	if result[0] != OK:
		return PackedByteArray()
	return result[1]
