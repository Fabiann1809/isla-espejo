class_name QrCode
extends RefCounted
## QR code encoder (ISO/IEC 18004): byte mode, versions 1-4, error correction level M.
## make_matrix() returns rows of bool (true = dark module) or null when the text is too long;
## make_image() draws it black on white with a quiet zone.

const MAX_VERSION := 4
## Level M per version (index = version): total codewords, EC codewords per block, block count.
## ISO/IEC 18004:2015 table 9. All blocks are the same size for versions 1-4 at level M.
const TOTAL_CODEWORDS: Array[int] = [0, 26, 44, 70, 100]
const EC_PER_BLOCK: Array[int] = [0, 10, 16, 26, 18]
const BLOCK_COUNT: Array[int] = [0, 1, 1, 1, 2]
## Alignment pattern centre coordinates (ISO/IEC 18004:2015 annex E). Version 1 has none.
const ALIGNMENT_POSITIONS: Array = [[], [], [6, 18], [6, 22], [6, 26]]
## Format information: level M is 00 (L=01, M=00, Q=11, H=10).
const EC_LEVEL_M_BITS := 0
const FORMAT_GENERATOR := 0x537
const FORMAT_XOR_MASK := 0x5412
const GF_PRIMITIVE := 0x11D
const PAD_BYTES: Array[int] = [0xEC, 0x11]
const MODE_BYTE := 0b0100


## Rows of bool (true = dark), or null when the UTF-8 text does not fit version 4-M.
static func make_matrix(text: String) -> Variant:
	var data := text.to_utf8_buffer()
	var version := version_for_length(data.size())
	if version == 0:
		return null
	var codewords := build_codewords(data, version)
	var size := 17 + 4 * version
	var modules := _grid(size)
	var function := _grid(size)
	_draw_function_patterns(modules, function, version)
	_place_data(modules, function, codewords)
	var best_mask := 0
	var best_penalty := -1
	for mask in 8:
		_apply_mask(modules, function, mask)
		_draw_format_bits(modules, function, mask)
		var penalty := penalty_score(modules)
		if best_penalty < 0 or penalty < best_penalty:
			best_penalty = penalty
			best_mask = mask
		_apply_mask(modules, function, mask)  # XOR again undoes it
	_apply_mask(modules, function, best_mask)
	_draw_format_bits(modules, function, best_mask)
	return modules


## Black-on-white image, each module module_px pixels, quiet_zone modules of white around it.
static func make_image(text: String, module_px: int = 4, quiet_zone: int = 4) -> Image:
	var matrix = make_matrix(text)
	if matrix == null:
		return null
	var px := maxi(module_px, 1)
	var border := maxi(quiet_zone, 0)
	var size: int = matrix.size()
	var side := (size + 2 * border) * px
	var image := Image.create_empty(side, side, false, Image.FORMAT_L8)
	image.fill(Color.WHITE)
	for y in size:
		for x in size:
			if matrix[y][x]:
				image.fill_rect(Rect2i((x + border) * px, (y + border) * px, px, px), Color.BLACK)
	return image


## Smallest version (1-4) whose level-M byte capacity holds `byte_count` bytes, or 0.
static func version_for_length(byte_count: int) -> int:
	for version in range(1, MAX_VERSION + 1):
		if byte_count <= byte_capacity(version):
			return version
	return 0


## Byte-mode capacity at level M: data bits minus the 4-bit mode and the 8-bit count.
static func byte_capacity(version: int) -> int:
	return (data_codeword_count(version) * 8 - 12) / 8


static func data_codeword_count(version: int) -> int:
	return TOTAL_CODEWORDS[version] - EC_PER_BLOCK[version] * BLOCK_COUNT[version]


## Data codewords (segment, terminator, padding) before error correction.
static func build_data_codewords(data: PackedByteArray, version: int) -> PackedByteArray:
	var capacity_bits := data_codeword_count(version) * 8
	var bits: Array[int] = []
	_append_bits(bits, MODE_BYTE, 4)
	_append_bits(bits, data.size(), 8)  # count indicator is 8 bits for versions 1-9
	for byte in data:
		_append_bits(bits, byte, 8)
	_append_bits(bits, 0, mini(4, capacity_bits - bits.size()))
	_append_bits(bits, 0, (8 - bits.size() % 8) % 8)
	var result := PackedByteArray()
	for i in range(0, bits.size(), 8):
		var value := 0
		for j in 8:
			value = (value << 1) | bits[i + j]
		result.append(value)
	var pad := 0
	while result.size() < data_codeword_count(version):
		result.append(PAD_BYTES[pad % 2])
		pad += 1
	return result


## Final codeword sequence: data split in blocks, EC added, both interleaved.
static func build_codewords(data: PackedByteArray, version: int) -> PackedByteArray:
	var data_codewords := build_data_codewords(data, version)
	var blocks := BLOCK_COUNT[version]
	var block_len := data_codewords.size() / blocks
	var ec_len := EC_PER_BLOCK[version]
	var divisor := rs_generator(ec_len)
	var data_blocks: Array[PackedByteArray] = []
	var ec_blocks: Array[PackedByteArray] = []
	for b in blocks:
		var block := data_codewords.slice(b * block_len, (b + 1) * block_len)
		data_blocks.append(block)
		ec_blocks.append(rs_remainder(block, divisor))
	var result := PackedByteArray()
	for i in block_len:
		for b in blocks:
			result.append(data_blocks[b][i])
	for i in ec_len:
		for b in blocks:
			result.append(ec_blocks[b][i])
	return result


## Product in GF(256) with the primitive polynomial x^8+x^4+x^3+x^2+1 (0x11D).
static func gf_multiply(x: int, y: int) -> int:
	var z := 0
	for i in range(7, -1, -1):
		z = (z << 1) ^ ((z >> 7) * GF_PRIMITIVE)
		z ^= ((y >> i) & 1) * x
	return z


## Coefficients of (x - a^0)(x - a^1)...(x - a^(degree-1)), highest power first, leading 1 dropped.
static func rs_generator(degree: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(degree)
	result[degree - 1] = 1
	var root := 1
	for i in degree:
		for j in degree:
			result[j] = gf_multiply(result[j], root)
			if j + 1 < degree:
				result[j] ^= result[j + 1]
		root = gf_multiply(root, 0x02)
	return result


## Remainder of data(x) * x^degree divided by the generator: the EC codewords.
static func rs_remainder(data: PackedByteArray, divisor: PackedByteArray) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(divisor.size())
	for byte in data:
		var factor := byte ^ result[0]
		result.remove_at(0)
		result.append(0)
		for i in divisor.size():
			result[i] ^= gf_multiply(divisor[i], factor)
	return result


## 15-bit format information for level M and `mask`: BCH(15,5) then XOR 0x5412.
static func format_bits(mask: int) -> int:
	var data := (EC_LEVEL_M_BITS << 3) | mask
	var rem := data
	for i in 10:
		rem = (rem << 1) ^ ((rem >> 9) * FORMAT_GENERATOR)
	return ((data << 10) | rem) ^ FORMAT_XOR_MASK


static func mask_dark(mask: int, x: int, y: int) -> bool:
	match mask:
		0: return (x + y) % 2 == 0
		1: return y % 2 == 0
		2: return x % 3 == 0
		3: return (x + y) % 3 == 0
		4: return (x / 3 + y / 2) % 2 == 0
		5: return (x * y) % 2 + (x * y) % 3 == 0
		6: return ((x * y) % 2 + (x * y) % 3) % 2 == 0
		7: return ((x + y) % 2 + (x * y) % 3) % 2 == 0
	return false


## Penalty rules N1-N4 of ISO/IEC 18004 section 7.8.3 (N1=3, N2=3, N3=40, N4=10).
static func penalty_score(modules: Array) -> int:
	var size := modules.size()
	var score := 0
	# Rule 1: runs of 5 or more same-coloured modules in a row or column.
	for horizontal in [true, false]:
		for a in size:
			var run := 0
			var last := false
			for b in size:
				var dark: bool = modules[a][b] if horizontal else modules[b][a]
				if b > 0 and dark == last:
					run += 1
				else:
					if run >= 5:
						score += 3 + run - 5
					run = 1
					last = dark
			if run >= 5:
				score += 3 + run - 5
	# Rule 2: 2x2 blocks of one colour.
	for y in size - 1:
		for x in size - 1:
			var c: bool = modules[y][x]
			if c == modules[y][x + 1] and c == modules[y + 1][x] and c == modules[y + 1][x + 1]:
				score += 3
	# Rule 3: 1:1:3:1:1 finder-like pattern with 4 light modules on one side.
	var pattern_a := [true, false, true, true, true, false, true, false, false, false, false]
	var pattern_b := [false, false, false, false, true, false, true, true, true, false, true]
	for horizontal in [true, false]:
		for a in size:
			for b in size - 10:
				var match_a := true
				var match_b := true
				for k in 11:
					var dark: bool = modules[a][b + k] if horizontal else modules[b + k][a]
					if dark != pattern_a[k]:
						match_a = false
					if dark != pattern_b[k]:
						match_b = false
				if match_a:
					score += 40
				if match_b:
					score += 40
	# Rule 4: 10 points per full 5% step away from 50% dark.
	var dark_count := 0
	for row in modules:
		for cell in row:
			if cell:
				dark_count += 1
	var total := size * size
	var deviation := absi(dark_count * 100 - total * 50)  # percent * total
	score += 10 * (deviation / (5 * total))
	return score


static func _grid(size: int) -> Array:
	var rows := []
	for y in size:
		var row := []
		row.resize(size)
		row.fill(false)
		rows.append(row)
	return rows


static func _append_bits(bits: Array[int], value: int, count: int) -> void:
	for i in range(count - 1, -1, -1):
		bits.append((value >> i) & 1)


static func _set_function(modules: Array, function: Array, x: int, y: int, dark: bool) -> void:
	modules[y][x] = dark
	function[y][x] = true


static func _draw_function_patterns(modules: Array, function: Array, version: int) -> void:
	var size := modules.size()
	for i in size:
		_set_function(modules, function, 6, i, i % 2 == 0)
		_set_function(modules, function, i, 6, i % 2 == 0)
	# Finders (centres 3 modules in) with their light separators.
	for centre in [Vector2i(3, 3), Vector2i(size - 4, 3), Vector2i(3, size - 4)]:
		for dy in range(-4, 5):
			for dx in range(-4, 5):
				var x: int = centre.x + dx
				var y: int = centre.y + dy
				if x < 0 or y < 0 or x >= size or y >= size:
					continue
				var dist := maxi(absi(dx), absi(dy))
				_set_function(modules, function, x, y, dist != 2 and dist != 4)
	# Alignment patterns, except the three that would overlap the finders.
	var positions: Array = ALIGNMENT_POSITIONS[version]
	var count := positions.size()
	for i in count:
		for j in count:
			if (i == 0 and j == 0) or (i == 0 and j == count - 1) or (i == count - 1 and j == 0):
				continue
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					_set_function(modules, function, positions[i] + dx, positions[j] + dy, maxi(absi(dx), absi(dy)) != 1)
	# Reserve the format areas (real bits are drawn per mask) and set the dark module.
	_draw_format_bits(modules, function, 0)
	# Version information exists only from version 7, so none is drawn here.


## Format bits in both copies (x = column, y = row), plus the dark module at (8, size-8).
static func _draw_format_bits(modules: Array, function: Array, mask: int) -> void:
	var size := modules.size()
	var bits := format_bits(mask)
	for i in 6:
		_set_function(modules, function, 8, i, _bit(bits, i))
	_set_function(modules, function, 8, 7, _bit(bits, 6))
	_set_function(modules, function, 8, 8, _bit(bits, 7))
	_set_function(modules, function, 7, 8, _bit(bits, 8))
	for i in range(9, 15):
		_set_function(modules, function, 14 - i, 8, _bit(bits, i))
	for i in 8:
		_set_function(modules, function, size - 1 - i, 8, _bit(bits, i))
	for i in range(8, 15):
		_set_function(modules, function, 8, size - 15 + i, _bit(bits, i))
	_set_function(modules, function, 8, size - 8, true)


static func _bit(value: int, index: int) -> bool:
	return ((value >> index) & 1) != 0


## Zigzag placement: two-column strips from the right, alternating up and down, skipping column 6.
static func _place_data(modules: Array, function: Array, codewords: PackedByteArray) -> void:
	var size := modules.size()
	var total_bits := codewords.size() * 8
	var i := 0
	var right := size - 1
	while right >= 1:
		if right == 6:
			right = 5
		var upward := ((right + 1) & 2) == 0
		for vert in size:
			var y: int = size - 1 - vert if upward else vert
			for j in 2:
				var x := right - j
				if not function[y][x] and i < total_bits:
					modules[y][x] = _bit(codewords[i >> 3], 7 - (i & 7))
					i += 1
		right -= 2
	# Remainder bits (7 for versions 2-4) stay light before masking, as the standard says.


static func _apply_mask(modules: Array, function: Array, mask: int) -> void:
	var size := modules.size()
	for y in size:
		for x in size:
			if not function[y][x] and mask_dark(mask, x, y):
				modules[y][x] = not modules[y][x]
