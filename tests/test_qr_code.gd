extends SceneTree
## QrCode test: tables, Reed-Solomon, format bits, function patterns and a full re-read of the
## matrix (zigzag, unmask, de-interleave, RS syndromes, byte segment) done independently here.
## Run: godot --headless --path . --script res://tests/test_qr_code.gd

const FORMAT_POLY := 0x537

var _ok := true
var _exp: Array[int] = []
var _log: Array[int] = []


func _initialize() -> void:
	_build_gf_tables()
	var qr = load("res://scripts/net/qr_code.gd")

	# Level M tables: data codewords and byte capacities (ISO/IEC 18004 table 7 and 9).
	var data_counts := [0, 16, 28, 44, 64]
	var capacities := [0, 14, 26, 42, 62]
	for v in range(1, 5):
		_check(qr.data_codeword_count(v) == data_counts[v], "version %d-M has %d data codewords" % [v, data_counts[v]])
		_check(qr.byte_capacity(v) == capacities[v], "version %d-M holds %d bytes" % [v, capacities[v]])

	# Format information known answers (level M, masks 0-7, bit 14 first).
	var format_strings := ["101010000010010", "101000100100101", "101111001111100", "101101101001011",
		"100010111111001", "100000011001110", "100111110010111", "100101010100000"]
	for m in 8:
		_check(qr.format_bits(m) == _bin(format_strings[m]), "format bits M mask %d" % m)
		_check(_valid_format(qr.format_bits(m)) == m, "format bits M mask %d are a BCH codeword" % m)

	# Reed-Solomon known answer: "HELLO WORLD" 1-M data codewords and their 10 EC codewords.
	var hello := PackedByteArray([32, 91, 11, 120, 209, 114, 220, 77, 67, 64, 236, 17, 236, 17, 236, 17])
	var hello_ec = qr.rs_remainder(hello, qr.rs_generator(10))
	_check(hello_ec == PackedByteArray([196, 35, 39, 119, 235, 215, 231, 226, 93, 23]), "RS known answer for HELLO WORLD 1-M")
	_check(_syndromes_zero(hello + hello_ec, 10), "RS codeword has zero syndromes")
	for degree in [16, 18, 26]:
		var sample := PackedByteArray()
		for i in 30:
			sample.append((i * 37 + degree) % 256)
		_check(_syndromes_zero(sample + qr.rs_remainder(sample, qr.rs_generator(degree)), degree), "RS degree %d has zero syndromes" % degree)

	# Byte segment known answer for "A": 0100 00000001 01000001 0000, then 0xEC/0x11 padding.
	var a_words = qr.build_data_codewords("A".to_utf8_buffer(), 1)
	var a_expected := PackedByteArray([0x40, 0x14, 0x10, 0xEC, 0x11, 0xEC, 0x11, 0xEC, 0x11, 0xEC, 0x11, 0xEC, 0x11, 0xEC, 0x11, 0xEC])
	_check(a_words == a_expected, "byte segment, terminator and padding for A")

	# Sizes: smallest version that fits; null past 62 bytes.
	var lengths := {0: 21, 1: 21, 14: 21, 15: 25, 26: 25, 27: 29, 42: 29, 43: 33, 62: 33}
	for n in lengths:
		var m = qr.make_matrix("x".repeat(n))
		_check(m != null and m.size() == lengths[n] and m[0].size() == lengths[n], "%d bytes -> %dx%d" % [n, lengths[n], lengths[n]])
	_check(qr.make_matrix("x".repeat(63)) == null, "63 bytes do not fit 4-M")
	_check(qr.make_image("x".repeat(63)) == null, "no image for 63 bytes")
	_check(qr.make_matrix("ñ".repeat(7)).size() == 21, "UTF-8 length counted in bytes (14 -> v1)")
	_check(qr.make_matrix("ñ".repeat(8)).size() == 25, "UTF-8 length counted in bytes (16 -> v2)")

	var texts := ["HELLO WORLD", "http://192.168.1.5:8080/", "http://192.168.100.200:8080/mando",
		"http://172.16.254.1:8080/ ñandú áéíóú", "x".repeat(62), ""]
	for text in texts:
		_check_symbol(qr, text)

	# Image: module size, quiet zone, colours.
	var image: Image = qr.make_image("HELLO WORLD", 4, 4)
	_check(image != null and image.get_width() == (21 + 8) * 4 and image.get_height() == image.get_width(), "image size with quiet zone")
	_check(image.get_pixel(0, 0).r > 0.9 and image.get_pixel(15, 15).r > 0.9, "quiet zone is white")
	_check(image.get_pixel(16, 16).r < 0.1 and image.get_pixel(19, 19).r < 0.1, "finder corner module is black")
	_check(image.get_pixel(16 + 4, 16 + 4).r > 0.9, "finder light ring is white")
	var small: Image = qr.make_image("HELLO WORLD", 1, 0)
	_check(small.get_width() == 21, "module_px 1 and no quiet zone")

	quit(0 if _ok else 1)


func _check_symbol(qr, text: String) -> void:
	var tag := "[%s]" % (text if text.length() < 20 else text.substr(0, 17) + "...")
	var m = qr.make_matrix(text)
	var size: int = m.size()
	var version := (size - 17) / 4
	var function := _function_map(size, version)

	# Finders and separators.
	for corner in [Vector2i(0, 0), Vector2i(size - 7, 0), Vector2i(0, size - 7)]:
		var finder_ok := true
		for dy in 7:
			for dx in 7:
				var dist := maxi(absi(dx - 3), absi(dy - 3))
				if m[corner.y + dy][corner.x + dx] != (dist != 2):
					finder_ok = false
		_check(finder_ok, "%s finder at %s" % [tag, corner])
	var sep_ok := true
	for i in 8:
		var light := [Vector2i(7, i), Vector2i(i, 7), Vector2i(size - 8, i), Vector2i(size - 1 - i, 7),
			Vector2i(7, size - 1 - i), Vector2i(i, size - 8)]
		for p in light:
			if m[p.y][p.x]:
				sep_ok = false
	_check(sep_ok, "%s separators are light" % tag)

	# Timing patterns between the finders.
	var timing_ok := true
	for i in range(8, size - 8):
		if m[6][i] != (i % 2 == 0) or m[i][6] != (i % 2 == 0):
			timing_ok = false
	_check(timing_ok, "%s timing patterns alternate" % tag)
	_check(m[size - 8][8] == true, "%s dark module set" % tag)

	# Alignment pattern (single one for versions 2-4, centre at size-7).
	if version >= 2:
		var c := size - 7
		var align_ok := true
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				if m[c + dy][c + dx] != (maxi(absi(dx), absi(dy)) != 1):
					align_ok = false
		_check(align_ok, "%s alignment pattern at (%d,%d)" % [tag, c, c])

	# Format information: both copies equal, a valid BCH codeword, level M.
	var copy1 := 0
	var copy2 := 0
	var first: Array[Vector2i] = []
	for i in 6:
		first.append(Vector2i(8, i))
	first.append_array([Vector2i(8, 7), Vector2i(8, 8), Vector2i(7, 8)])
	for i in range(9, 15):
		first.append(Vector2i(14 - i, 8))
	var second: Array[Vector2i] = []
	for i in 8:
		second.append(Vector2i(size - 1 - i, 8))
	for i in range(8, 15):
		second.append(Vector2i(8, size - 15 + i))
	for i in 15:
		if m[first[i].y][first[i].x]:
			copy1 |= 1 << i
		if m[second[i].y][second[i].x]:
			copy2 |= 1 << i
	var mask := _valid_format(copy1)
	_check(copy1 == copy2, "%s format copies match" % tag)
	_check(mask >= 0, "%s format is a valid level-M BCH codeword (mask %d)" % [tag, mask])
	if mask < 0:
		return

	# Module count matches the codeword table (remainder bits: 0 for v1, 7 for v2-4).
	var free := 0
	for y in size:
		for x in size:
			if not function[y][x]:
				free += 1
	var total_codewords: int = [0, 26, 44, 70, 100][version]
	_check(free == total_codewords * 8 + (0 if version == 1 else 7), "%s data module count matches %d codewords" % [tag, total_codewords])

	# The chosen mask has the lowest penalty among the 8.
	var base := _unmasked(m, function, mask)
	var best := true
	var chosen_score: int = qr.penalty_score(m)
	for other in 8:
		var candidate := _masked(base, function, other)
		qr._draw_format_bits(candidate, _grid(size), other)
		if qr.penalty_score(candidate) < chosen_score:
			best = false
	_check(best, "%s mask %d has the lowest penalty" % [tag, mask])

	# Zigzag re-read: column pairs from the right, skipping column 6, direction flips per pair.
	var bits: Array[int] = []
	var col := size - 1
	var going_up := true
	while col > 0:
		if col == 6:
			col -= 1
		var rows: Array = range(size - 1, -1, -1) if going_up else range(size)
		for y in rows:
			for x in [col, col - 1]:
				if not function[y][x]:
					bits.append(1 if base[y][x] else 0)
		going_up = not going_up
		col -= 2
	var codewords := PackedByteArray()
	for i in total_codewords:
		var value := 0
		for j in 8:
			value = (value << 1) | bits[i * 8 + j]
		codewords.append(value)
	var remainder_ok := true
	for i in range(total_codewords * 8, bits.size()):
		if bits[i] != 0:
			remainder_ok = false
	_check(remainder_ok, "%s remainder bits are 0 before masking" % tag)

	# De-interleave and check every block's Reed-Solomon syndromes.
	var blocks: int = [0, 1, 1, 1, 2][version]
	var ec_len: int = [0, 10, 16, 26, 18][version]
	var data_len := (total_codewords - blocks * ec_len) / blocks
	var data := PackedByteArray()
	var rs_ok := true
	for b in blocks:
		var block := PackedByteArray()
		for i in data_len:
			block.append(codewords[i * blocks + b])
		data.append_array(block)
		for i in ec_len:
			block.append(codewords[data_len * blocks + i * blocks + b])
		if not _syndromes_zero(block, ec_len):
			rs_ok = false
	_check(rs_ok, "%s every RS block has zero syndromes" % tag)

	# Byte segment decodes back to the text, then terminator and 0xEC/0x11 padding.
	var payload := text.to_utf8_buffer()
	var mode := data[0] >> 4
	var count := ((data[0] & 0x0F) << 4) | (data[1] >> 4)
	var decoded := PackedByteArray()
	for i in count:
		decoded.append(((data[1 + i] & 0x0F) << 4) | (data[2 + i] >> 4))
	_check(mode == 0b0100 and count == payload.size() and decoded == payload, "%s byte segment decodes to the text" % tag)
	var pad_ok := (data[1 + count] & 0x0F) == 0
	for i in range(2 + count, data.size()):
		if data[i] != [0xEC, 0x11][(i - 2 - count) % 2]:
			pad_ok = false
	_check(pad_ok, "%s terminator and pad bytes" % tag)


## Function modules for versions 1-4, built here independently of the encoder.
func _function_map(size: int, version: int) -> Array:
	var f := _grid(size)
	for y in size:
		for x in size:
			var in_finder := (x < 9 and y < 9) or (x >= size - 8 and y < 9) or (x < 9 and y >= size - 8)
			var timing := x == 6 or y == 6
			var align := version >= 2 and absi(x - (size - 7)) <= 2 and absi(y - (size - 7)) <= 2
			f[y][x] = in_finder or timing or align
	return f


func _grid(size: int) -> Array:
	var rows := []
	for y in size:
		var row := []
		row.resize(size)
		row.fill(false)
		rows.append(row)
	return rows


func _mask_bit(mask: int, row: int, col: int) -> bool:
	var i := row
	var j := col
	match mask:
		0: return (i + j) % 2 == 0
		1: return i % 2 == 0
		2: return j % 3 == 0
		3: return (i + j) % 3 == 0
		4: return (floori(i / 2.0) + floori(j / 3.0)) % 2 == 0
		5: return (i * j) % 2 + (i * j) % 3 == 0
		6: return ((i * j) % 2 + (i * j) % 3) % 2 == 0
		7: return ((i * j) % 3 + (i + j) % 2) % 2 == 0
	return false


func _unmasked(m: Array, function: Array, mask: int) -> Array:
	return _masked(m, function, mask)


func _masked(m: Array, function: Array, mask: int) -> Array:
	var out := []
	for y in m.size():
		var row := []
		for x in m.size():
			var v: bool = m[y][x]
			if not function[y][x] and _mask_bit(mask, y, x):
				v = not v
			row.append(v)
		out.append(row)
	return out


## Mask number if `bits` is a valid level-M format codeword, else -1.
func _valid_format(bits: int) -> int:
	var raw := bits ^ 0x5412
	var rem := raw
	for shift in range(4, -1, -1):
		if rem & (1 << (shift + 10)):
			rem ^= FORMAT_POLY << shift
	if rem != 0:
		return -1
	var data := raw >> 10
	if (data >> 3) != 0:  # level M is 00
		return -1
	return data & 7


func _build_gf_tables() -> void:
	_exp.resize(512)
	_log.resize(256)
	var x := 1
	for i in 255:
		_exp[i] = x
		_log[x] = i
		x <<= 1
		if x & 0x100:
			x ^= 0x11D
	for i in range(255, 512):
		_exp[i] = _exp[i - 255]


## Codeword (highest power first) evaluated at a^0..a^(ec-1) must be 0 for a valid RS block.
func _syndromes_zero(codeword: PackedByteArray, ec: int) -> bool:
	for i in ec:
		var s := 0
		for c in codeword:
			s = (0 if s == 0 else _exp[_log[s] + i]) ^ c
		if s != 0:
			return false
	return true


func _bin(text: String) -> int:
	var v := 0
	for ch in text:
		v = (v << 1) | (1 if ch == "1" else 0)
	return v


func _check(condition: bool, label: String) -> void:
	if condition:
		print("PASS ", label)
	else:
		print("FAIL ", label)
		_ok = false
