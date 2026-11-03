extends SceneTree
## ControlServer test: pure HTTP/WebSocket helpers, limits and the headless guard.
## Never binds a real port.
## Run: godot --headless --path . --script res://tests/test_control_server.gd

var _ok := true


func _initialize() -> void:
	var server_script = load("res://scripts/net/control_server.gd")

	# Request line.
	var line = server_script.parse_request_line("GET /ws?x=1 HTTP/1.1")
	_check(line.get("method") == "GET" and line.get("path") == "/ws?x=1" and line.get("version") == "HTTP/1.1", "request line parsed")
	_check(server_script.parse_request_line("GET /").is_empty(), "request line without version rejected")
	_check(server_script.parse_request_line("GET ws HTTP/1.1").is_empty(), "path must start with /")
	_check(server_script.parse_request_line("hello world foo").is_empty(), "garbage request line rejected")
	_check(server_script.request_path({"path": "/ws?token=1"}) == "/ws", "query stripped from path")

	# Headers, case-insensitive.
	var head := "GET /ws HTTP/1.1\r\nHost: 192.168.1.5:8080\r\nUPGRADE: WebSocket\r\nConnection: keep-alive, Upgrade\r\nSec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\nSec-WebSocket-Version: 13"
	var request = server_script.parse_request(head)
	_check(not request.is_empty(), "request head parsed")
	_check(server_script.header_value(request["headers"], "upgrade") == "WebSocket", "header lookup lower-case name")
	_check(server_script.header_value(request["headers"], "Sec-WebSocket-Key") == "dGhlIHNhbXBsZSBub25jZQ==", "header lookup mixed-case name")
	_check(server_script.header_value({"X-Mixed": "a"}, "x-mixed") == "a", "lookup works on non-normalised keys")
	_check(server_script.header_value(request["headers"], "missing") == "", "missing header is empty")

	# Upgrade detection.
	_check(server_script.is_websocket_upgrade(request), "websocket upgrade on /ws detected")
	_check(not server_script.is_websocket_upgrade(server_script.parse_request("GET / HTTP/1.1\r\nHost: x")), "plain GET is not an upgrade")
	_check(not server_script.is_websocket_upgrade(server_script.parse_request(head.replace("GET /ws", "GET /other"))), "upgrade on another path rejected")
	_check(not server_script.is_websocket_upgrade(server_script.parse_request(head.replace("keep-alive, Upgrade", "keep-alive"))), "upgrade without Connection: Upgrade rejected")
	_check(not server_script.is_websocket_upgrade(server_script.parse_request(head.replace("Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==\r\n", ""))), "upgrade without key rejected")
	_check(not server_script.is_websocket_upgrade(server_script.parse_request(head.replace("GET /ws", "POST /ws"))), "non-GET upgrade rejected")

	# Handshake known answer (RFC 6455 section 1.3).
	_check(server_script.websocket_accept_key("dGhlIHNhbXBsZSBub25jZQ==") == "s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", "Sec-WebSocket-Accept matches RFC 6455")
	var raw := ("GET / HTTP/1.1\r\nHost: x\r\n\r\nrest").to_utf8_buffer()
	_check(server_script.find_header_end(raw) == raw.size() - 4, "end of request head found")
	_check(server_script.find_header_end("GET / HTTP/1.1\r\nHost".to_utf8_buffer()) == -1, "incomplete head not found")
	var response: String = server_script.http_response("404 Not Found", "text/plain", "Nope".to_utf8_buffer()).get_string_from_utf8()
	_check(response.begins_with("HTTP/1.1 404 Not Found\r\n") and response.contains("Content-Length: 4\r\n") and response.ends_with("\r\n\r\nNope"), "HTTP response built")

	# Frames: a masked client text frame decodes; partial frames wait; unmasked ones are errors.
	var frame := _masked_text_frame("{\"type\":\"ping\"}", PackedByteArray([1, 2, 3, 4]))
	var decoded = server_script.decode_frame(frame)
	_check(decoded.get("opcode") == 1 and decoded.get("fin") == true, "text frame decoded")
	_check(decoded.get("payload", PackedByteArray()).get_string_from_utf8() == "{\"type\":\"ping\"}", "payload unmasked")
	_check(decoded.get("size") == frame.size(), "frame size reported")
	_check(server_script.decode_frame(frame.slice(0, frame.size() - 1)).is_empty(), "partial frame waits")
	_check(server_script.decode_frame(server_script.encode_text("hi")).has("error"), "unmasked client frame rejected")
	var long_text := "x".repeat(300)
	var long_frame := _masked_text_frame(long_text, PackedByteArray([9, 8, 7, 6]))
	_check(server_script.decode_frame(long_frame).get("payload", PackedByteArray()).get_string_from_utf8() == long_text, "16-bit length frame decoded")
	_check(server_script.decode_frame(long_frame, 100).has("error"), "oversized frame rejected")
	var server_frame: PackedByteArray = server_script.encode_text("{\"type\":\"busy\"}")
	_check(server_frame[0] == 0x81 and server_frame[1] == 15, "server text frame header")
	var close: PackedByteArray = server_script.encode_close(1013)
	_check(close == PackedByteArray([0x88, 2, 0x03, 0xF5]), "close frame carries the code")

	# Messages: only Dictionaries pass.
	_check(server_script.parse_message("{\"type\":\"ping\"}") is Dictionary, "JSON object accepted")
	_check(server_script.parse_message("[1,2]") == null, "JSON array ignored")
	_check(server_script.parse_message("42") == null, "JSON number ignored")
	_check(server_script.parse_message("not json") == null, "invalid JSON ignored")

	# Rate limit: 60 per second, then a new window.
	var state := {}
	var allowed := 0
	for i in 100:
		if server_script.rate_allow(state, 1000 + i):
			allowed += 1
	_check(allowed == 60, "at most 60 messages accepted in one second")
	_check(not server_script.rate_allow(state, 1999), "still limited before the window ends")
	_check(server_script.rate_allow(state, 2000), "new window accepts again")

	# Frame budget: every frame counts, 120 per second, separate from the 60 messages.
	_check(server_script.MAX_FRAMES_PER_SECOND == 120, "frame budget is 120 per second")
	var frame_state := {}
	var frames_allowed := 0
	for i in 200:
		if server_script.rate_allow(frame_state, 5000 + i, server_script.MAX_FRAMES_PER_SECOND):
			frames_allowed += 1
	_check(frames_allowed == 120, "frame budget stops at 120 in one second")
	_check(not server_script.rate_allow(frame_state, 5999, server_script.MAX_FRAMES_PER_SECOND), "frame budget still exceeded before the window ends")
	_check(server_script.rate_allow(frame_state, 6000, server_script.MAX_FRAMES_PER_SECOND), "frame budget resets after one second")

	# Frames decoded by offset, without copying the buffer per frame.
	var pair := _masked_text_frame("{\"a\":1}", PackedByteArray([5, 6, 7, 8]))
	var first_size := pair.size()
	pair.append_array(_masked_text_frame("{\"b\":2}", PackedByteArray([1, 1, 1, 1])))
	var second = server_script.decode_frame(pair, 4096, first_size)
	_check(second.get("payload", PackedByteArray()).get_string_from_ascii() == "{\"b\":2}", "second frame decoded at its offset")
	_check(second.get("size") == pair.size() - first_size, "size is the frame length, not the end offset")
	_check(server_script.decode_frame(pair, 4096, pair.size() - 1).is_empty(), "one byte at the end waits for more")

	# ASCII check: request heads and controller messages are plain ASCII.
	_check(server_script.is_ascii("{\"type\":\"ping\"}".to_ascii_buffer()), "ASCII message accepted")
	_check(server_script.is_ascii(PackedByteArray()), "empty bytes count as ASCII")
	_check(not server_script.is_ascii(PackedByteArray([0x7B, 0xC3, 0xB1, 0x7D])), "UTF-8 bytes rejected")
	_check(not server_script.is_ascii(PackedByteArray([0xFF])), "0xFF rejected")
	_check(server_script.is_ascii(PackedByteArray([0x7F])), "0x7F is still ASCII")

	# Heartbeat silence.
	_check(not server_script.is_silent(1000, 5999), "4.999 s of silence keeps the controller")
	_check(server_script.is_silent(1000, 6000), "5 s of silence drops the controller")

	# Private address filter.
	var filtered = server_script.filter_private_ipv4(PackedStringArray([
		"127.0.0.1", "172.20.1.2", "fe80:0:0:0:1", "10.0.0.7", "8.8.8.8", "192.168.1.40",
		"169.254.3.4", "172.32.0.1", "172.15.0.1", "192.169.0.1", "300.1.1.1", "10.0.0",
	]))
	_check(filtered == PackedStringArray(["192.168.1.40", "10.0.0.7", "172.20.1.2"]), "only private IPv4 kept, 192.168 first (got %s)" % [filtered])
	_check(server_script.is_private_ipv4("172.31.255.255") and not server_script.is_private_ipv4("172.32.0.0"), "172.16-31 range edges")
	# Interfaces: real adapters first, virtual ones (VirtualBox, hosted network, WSL...) last.
	var vbox := {"name": "{GUID-1}", "friendly": "VirtualBox Host-Only Network", "index": "9",
			"addresses": ["fe80:0:0:0:1", "192.168.56.1"]}
	var hosted := {"name": "{GUID-2}", "friendly": "Conexión de área local* 10", "index": "12",
			"addresses": ["192.168.137.1"]}
	var wsl := {"name": "{GUID-3}", "friendly": "vEthernet (WSL)", "index": "30", "addresses": ["172.20.48.1"]}
	var loopback := {"name": "{GUID-4}", "friendly": "Loopback Pseudo-Interface 1", "index": "1",
			"addresses": ["0:0:0:0:0:0:0:1", "127.0.0.1"]}
	var wifi := {"name": "{GUID-5}", "friendly": "Wi-Fi", "index": "5",
			"addresses": ["fe80:0:0:0:2", "10.0.0.7"]}
	var ethernet := {"name": "eth0", "friendly": "eth0", "index": "2", "addresses": PackedStringArray(["192.168.1.40"])}
	var picked = server_script.addresses_from_interfaces([vbox, hosted, wsl, loopback, wifi, ethernet])
	_check(picked == PackedStringArray(["192.168.1.40", "10.0.0.7", "192.168.56.1", "192.168.137.1", "172.20.48.1"]),
			"real adapters first, then virtual ones (got %s)" % [picked])
	_check(server_script.addresses_from_interfaces([vbox, hosted, loopback]) == PackedStringArray(["192.168.56.1", "192.168.137.1"]),
			"only virtual adapters: their addresses are still used")
	_check(server_script.addresses_from_interfaces([]).is_empty(), "no interfaces, no addresses")
	_check(server_script.addresses_from_interfaces([wifi, wifi, "junk", {"name": "x", "addresses": 5}]) == PackedStringArray(["10.0.0.7"]),
			"duplicates and malformed entries ignored")
	for name in ["VMware Network Adapter VMnet8", "vboxnet0", "Hyper-V Virtual Ethernet Adapter", "docker0",
			"TAP-Windows Adapter V9", "vEthernet (Default Switch)", "WSL", "lo Loopback",
			"virbr0", "vmnet1", "br-3f2a9c1d7e44", "Network Bridge"]:
		_check(server_script.is_virtual_interface({"name": name}), "virtual interface: %s" % name)
	for name in ["Wi-Fi", "Ethernet", "wlan0", "eth0", "en0", "Conexión de red inalámbrica"]:
		_check(not server_script.is_virtual_interface({"name": "{GUID}", "friendly": name}), "real interface: %s" % name)
	for address in server_script.lan_addresses():
		_check(server_script.is_private_ipv4(address), "lan_addresses returns private %s" % address)

	# Headless guard: no port is ever opened here.
	var server = server_script.new()
	_check(server.start(8080) == ERR_UNAVAILABLE, "start returns ERR_UNAVAILABLE in headless")
	_check(not server.is_running(), "server not running after a refused start")
	server.stop()
	server.free()

	print("Executed control server checks")
	quit(0 if _ok else 1)


func _masked_text_frame(text: String, mask: PackedByteArray) -> PackedByteArray:
	var payload := text.to_utf8_buffer()
	var frame := PackedByteArray([0x81])
	if payload.size() < 126:
		frame.append(0x80 | payload.size())
	else:
		frame.append_array(PackedByteArray([0x80 | 126, payload.size() >> 8, payload.size() & 0xFF]))
	frame.append_array(mask)
	for i in payload.size():
		frame.append(payload[i] ^ mask[i % 4])
	return frame


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		_ok = false
