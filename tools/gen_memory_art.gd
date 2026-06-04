extends Node
## Dev-only generator: procedurally builds a symbolic image for each recovered memory,
## in the game's warm autumn palette, for the jigsaw mini-game. Square images so they
## slice cleanly into a grid. Deterministic, headless, no external assets. Re-run to
## regenerate. Run: godot --headless res://tools/gen_memory_art.tscn

const ART_DIR: String = "res://assets/art/memories/"
const S: int = 240   # square side


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ART_DIR))
	_gen_treehouse()
	_gen_porch()
	_gen_kitchen()
	_gen_first_words()
	_gen_whole()
	print("=== memory art generated ===")
	get_tree().quit(0)


# --- image helpers (same style as gen_pixel_art.gd) ---

func _new() -> Image:
	return Image.create(S, S, false, Image.FORMAT_RGBA8)


func _in(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height()


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if _in(img, x, y):
		img.set_pixel(x, y, c)


func _blend(img: Image, x: int, y: int, c: Color, t: float) -> void:
	if not _in(img, x, y):
		return
	var base: Color = img.get_pixel(x, y)
	img.set_pixel(x, y, base.lerp(c, clampf(t, 0.0, 1.0)))


func _fill(img: Image, top: Color, bot: Color) -> void:
	for y in S:
		var t: float = float(y) / float(S)
		var row: Color = top.lerp(bot, pow(t, 0.9))
		for x in S:
			img.set_pixel(x, y, row)


func _rect(img: Image, x0: int, y0: int, w: int, h: int, c: Color) -> void:
	for y in range(y0, y0 + h):
		for x in range(x0, x0 + w):
			_px(img, x, y, c)


func _vgrad(img: Image, x0: int, y0: int, w: int, h: int, top: Color, bot: Color) -> void:
	for y in range(y0, y0 + h):
		var t: float = float(y - y0) / maxf(1.0, float(h))
		var row: Color = top.lerp(bot, t)
		for x in range(x0, x0 + w):
			_px(img, x, y, row)


func _frame(img: Image, x0: int, y0: int, w: int, h: int, c: Color, th: int = 3) -> void:
	for t in range(th):
		for x in range(x0 - t, x0 + w + t):
			_px(img, x, y0 - 1 - t, c)
			_px(img, x, y0 + h + t, c)
		for y in range(y0 - t, y0 + h + t):
			_px(img, x0 - 1 - t, y, c)
			_px(img, x0 + w + t, y, c)


func _disc(img: Image, cx: int, cy: int, r: float, c: Color) -> void:
	for y in range(int(cy - r), int(cy + r + 1)):
		for x in range(int(cx - r), int(cx + r + 1)):
			if Vector2(x - cx, y - cy).length() <= r:
				_px(img, x, y, c)


func _glow(img: Image, cx: int, cy: int, r: float, c: Color) -> void:
	for y in range(int(cy - r), int(cy + r + 1)):
		for x in range(int(cx - r), int(cx + r + 1)):
			var d: float = Vector2(x - cx, y - cy).length()
			if d <= r:
				_blend(img, x, y, c, 1.0 - d / r)


func _stars(img: Image, count: int, max_y: int, seed_val: int) -> void:
	var s: int = seed_val
	for i in count:
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var x: int = s % S
		s = (s * 1103515245 + 12345) & 0x7fffffff
		var y: int = s % max_y
		_blend(img, x, y, Color("#fff2cf"), 0.4 + 0.5 * float(s % 100) / 100.0)


func _save(img: Image, name: String) -> void:
	var err := img.save_png(ART_DIR + name)
	if err != OK:
		push_error("gen_memory_art: failed to save %s (err %d)" % [name, err])


# --- the memories ---

## The Treehouse: a small lit fort up a dark tree, a warm flashlight glow within.
func _gen_treehouse() -> void:
	var img := _new()
	_fill(img, Color("#241a30"), Color("#3a2b40"))
	_stars(img, 70, 150, 9001)
	_glow(img, 70, 54, 34.0, Color("#f3e6c8"))   # moon
	_disc(img, 70, 54, 16.0, Color("#f7eed6"))
	# Tree trunk + canopy.
	_rect(img, 150, 150, 22, 90, Color("#2e1f18"))
	_disc(img, 161, 150, 46.0, Color("#3a2a1e"))
	# The fort: a wooden box with a glowing window and a small door.
	_rect(img, 120, 110, 84, 64, Color("#6b4a30"))
	_frame(img, 120, 110, 84, 64, Color("#2e1d12"), 3)
	_glow(img, 150, 142, 24.0, Color("#ffd486"))   # flashlight warmth
	_rect(img, 138, 126, 24, 24, Color("#ffe6ad"))  # window
	_frame(img, 138, 126, 24, 24, Color("#3a2614"), 2)
	_rect(img, 172, 134, 16, 40, Color("#3a2614"))  # door
	_save(img, "mem_treehouse.png")


## The Porch: a step under a porch light, two small huddled shapes sharing warmth.
func _gen_porch() -> void:
	var img := _new()
	_fill(img, Color("#2c2336"), Color("#5a3f49"))
	_glow(img, 180, 40, 30.0, Color("#ffdf9e"))    # porch light
	_disc(img, 180, 40, 7.0, Color("#fff0c4"))
	# House wall + a door behind.
	_rect(img, 40, 60, 160, 120, Color("#43303a"))
	_rect(img, 150, 70, 44, 100, Color("#5a4030"))
	_frame(img, 150, 70, 44, 100, Color("#2a1c16"), 2)
	# The step.
	_rect(img, 0, 176, S, 64, Color("#3a2a26"))
	_rect(img, 0, 176, S, 8, Color("#4e3830"))
	# Two huddled silhouettes sharing one "coat".
	_disc(img, 96, 150, 16.0, Color("#1d1620"))
	_disc(img, 124, 152, 15.0, Color("#1d1620"))
	_rect(img, 82, 158, 60, 30, Color("#241a28"))  # shared blanket/coat
	_glow(img, 110, 160, 26.0, Color("#d99a58"))   # warmth between them
	_save(img, "mem_porch.png")


## The Kitchen Doorway: bright light spilling through a doorway, a small figure within.
func _gen_kitchen() -> void:
	var img := _new()
	_fill(img, Color("#241c20"), Color("#3a2a24"))   # dim hallway
	# The lit doorway.
	_vgrad(img, 84, 30, 96, 188, Color("#ffe6ad"), Color("#f0b06a"))
	_frame(img, 84, 30, 96, 188, Color("#2a1c14"), 4)
	_glow(img, 132, 90, 40.0, Color("#fff3c8"))
	# A small child silhouette standing in the doorway.
	_disc(img, 132, 120, 13.0, Color("#3a2418"))
	_rect(img, 120, 132, 24, 64, Color("#3a2418"))
	# Floor.
	_rect(img, 0, 210, S, 30, Color("#1f1712"))
	_save(img, "mem_kitchen.png")


## The First 'We': a journal page, the handwriting changing colour halfway down.
func _gen_first_words() -> void:
	var img := _new()
	_fill(img, Color("#3a2c22"), Color("#4a382a"))   # desk
	_glow(img, 40, 30, 60.0, Color("#e9b96a"))       # lamp
	# The page.
	_rect(img, 48, 40, 144, 168, Color("#efe7d2"))
	_frame(img, 48, 40, 144, 168, Color("#b7a988"), 2)
	# Ruled lines — top half one ink, bottom half another (the handwriting change).
	for i in 12:
		var ly: int = 58 + i * 12
		var ink: Color = Color("#5a4a36") if i < 6 else Color("#3a5a7a")
		for x in range(60, 180):
			if (x + i) % 3 != 0:   # dashed -> reads as handwriting
				_blend(img, x, ly, ink, 0.7)
	# A small star where the two hands meet.
	_disc(img, 120, 126, 3.0, Color("#caa05e"))
	_save(img, "mem_first_words.png")


## The Whole of It: dawn, warm gold, the motifs overlapping as one — door, house, stars.
func _gen_whole() -> void:
	var img := _new()
	_fill(img, Color("#3a4a78"), Color("#f2c27a"))
	_stars(img, 40, 90, 4242)
	# Rising sun with broad glow.
	_glow(img, 120, 150, 90.0, Color("#ffe6a8"))
	_glow(img, 120, 150, 44.0, Color("#fff0c4"))
	_disc(img, 120, 150, 24.0, Color("#fff6da"))
	# Faint overlapping shapes: a door, a little house — "many held as one".
	_frame(img, 60, 96, 36, 80, Color("#7a5236"), 2)     # door
	_frame(img, 150, 110, 60, 60, Color("#6e4d33"), 2)   # house
	_px(img, 180, 110, Color("#6e4d33"))
	# Gentle hills catching the light.
	var hills := [
		{"base": 196, "amp": 10.0, "freq": 0.02, "phase": 1.2, "color": Color("#caa05e")},
		{"base": 216, "amp": 12.0, "freq": 0.03, "phase": 3.7, "color": Color("#8f6a3c")},
	]
	for layer in hills:
		for x in S:
			var hy: int = int(layer["base"] - layer["amp"] * sin(x * layer["freq"] + layer["phase"]))
			for y in range(hy, S):
				_px(img, x, y, layer["color"])
	_save(img, "mem_whole.png")
