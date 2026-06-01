extends Node
## Dev-only generator: procedurally builds the game's pixel-art assets with Godot's
## Image API (works headless, fully deterministic, no external downloads) and saves
## them as PNGs under res://assets/art/. Re-run to regenerate.
## Run: godot --headless res://tools/gen_pixel_art.tscn

const ART_DIR: String = "res://assets/art/"
const BG_W: int = 320
const BG_H: int = 180

# Alter palette (kept in sync with data/alters.json).
const ALTERS := {
	"manager": {"color": "#c9a86a", "mouth": "calm"},
	"iris": {"color": "#9a6b9d", "mouth": "firm"},
	"rowan": {"color": "#cf7a4e", "mouth": "focused"},
	"june": {"color": "#6f9a7b", "mouth": "smile"},
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ART_DIR))
	_gen_external_bg()
	_gen_internal_bg()
	_gen_title_bg()
	_gen_leaves()
	for id in ALTERS:
		_gen_portrait(id, Color(ALTERS[id]["color"]), ALTERS[id]["mouth"])
	print("=== pixel art generated ===")
	get_tree().quit(0)


# --- helpers ---

func _new_img(w: int, h: int) -> Image:
	return Image.create(w, h, false, Image.FORMAT_RGBA8)


func _in(img: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height()


func _px(img: Image, x: int, y: int, c: Color) -> void:
	if _in(img, x, y):
		img.set_pixel(x, y, c)


## Alpha-aware blend onto existing pixel.
func _blend(img: Image, x: int, y: int, c: Color, t: float) -> void:
	if not _in(img, x, y):
		return
	var base: Color = img.get_pixel(x, y)
	img.set_pixel(x, y, base.lerp(c, clampf(t, 0.0, 1.0)))


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


func _save(img: Image, name: String) -> void:
	var err := img.save_png(ART_DIR + name)
	if err != OK:
		push_error("gen_pixel_art: failed to save %s (err %d)" % [name, err])


# --- backgrounds ---

func _gen_external_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	var sky_top := Color("#6d5a86")
	var sky_bot := Color("#e8a87c")
	for y in BG_H:
		var t: float = float(y) / float(BG_H)
		var row: Color = sky_top.lerp(sky_bot, pow(t, 0.8))
		for x in BG_W:
			img.set_pixel(x, y, row)
	# Soft sun.
	_glow(img, 252, 46, 34.0, Color("#ffdfa0"))
	_disc(img, 252, 46, 15.0, Color("#ffe9bd"))
	# Distant birds.
	for b in [[60, 38], [72, 44], [200, 30]]:
		var bx: int = b[0]
		var by: int = b[1]
		for d in range(-2, 3):
			_px(img, bx + d, by + absi(d) / 2, Color("#5b4a63"))
			_px(img, bx + 6 + d, by + 2 + absi(d) / 2, Color("#5b4a63"))
	# Layered autumn hills (back -> front).
	var layers := [
		{"base": 116, "amp": 10.0, "freq": 0.018, "phase": 0.0, "color": Color("#b06a44")},
		{"base": 132, "amp": 14.0, "freq": 0.024, "phase": 2.1, "color": Color("#8f5238")},
		{"base": 150, "amp": 12.0, "freq": 0.031, "phase": 4.4, "color": Color("#6e3e2c")},
	]
	for layer in layers:
		for x in BG_W:
			var hy: int = int(layer["base"] - layer["amp"] * sin(x * layer["freq"] + layer["phase"]))
			for y in range(hy, BG_H):
				img.set_pixel(x, y, layer["color"])
	# A few cozy trees on the front hill.
	for tx in [40, 96, 150, 210, 280]:
		var ground: int = int(150 - 12.0 * sin(tx * 0.031 + 4.4)) + 2
		_px(img, tx, ground - 1, Color("#4a2f22"))
		_px(img, tx, ground - 2, Color("#4a2f22"))
		_disc(img, tx, ground - 6, 5.0, Color("#c4632f"))
		_disc(img, tx - 3, ground - 4, 3.0, Color("#b8482a"))
		_disc(img, tx + 3, ground - 5, 3.0, Color("#d98a3d"))
	_save(img, "bg_external.png")


func _gen_internal_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	var center := Vector2(160, 86)
	var glow := Color("#463349")
	var edge := Color("#161019")
	var max_d: float = 200.0
	for y in BG_H:
		for x in BG_W:
			var d: float = Vector2(x - center.x, y - center.y).length() / max_d
			img.set_pixel(x, y, glow.lerp(edge, clampf(d, 0.0, 1.0)))
	# Scattered soft "synapse" motes (deterministic pseudo-random).
	var seed_val: int = 1337
	for i in 90:
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var x: int = seed_val % BG_W
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var y: int = seed_val % BG_H
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var warm: Color = [Color("#8a6f9e"), Color("#a98a6a"), Color("#6f9a7b")][seed_val % 3]
		_glow(img, x, y, 2.5, warm)
		_px(img, x, y, warm.lerp(Color.WHITE, 0.3))
	_save(img, "bg_internal.png")


func _gen_title_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	var top := Color("#241a30")
	var bot := Color("#7a4f57")
	for y in BG_H:
		var t: float = float(y) / float(BG_H)
		var row: Color = top.lerp(bot, pow(t, 1.2))
		for x in BG_W:
			img.set_pixel(x, y, row)
	# Stars.
	var seed_val: int = 9001
	for i in 70:
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var x: int = seed_val % BG_W
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var y: int = (seed_val % 110)
		_blend(img, x, y, Color("#fff2cf"), 0.5 + 0.5 * float(seed_val % 100) / 100.0)
	# Moon.
	_glow(img, 70, 50, 30.0, Color("#f3e6c8"))
	_disc(img, 70, 50, 16.0, Color("#f7eed6"))
	_disc(img, 78, 46, 13.0, top.lerp(bot, 0.18))   # crescent carve
	# Hill silhouette at the bottom.
	for x in BG_W:
		var hy: int = int(150 - 10.0 * sin(x * 0.02 + 1.0))
		for y in range(hy, BG_H):
			img.set_pixel(x, y, Color("#1c1422"))
	_save(img, "bg_title.png")


# --- leaves (particle sprites) ---

func _gen_leaves() -> void:
	var palette := [Color("#cf7a4e"), Color("#b8482f"), Color("#d9a441")]
	for i in palette.size():
		var img := _new_img(8, 8)
		var c: Color = palette[i]
		# Simple leaf: diamond body with a center vein.
		var body := [
			Vector2i(3, 0), Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1),
			Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2), Vector2i(5, 2),
			Vector2i(1, 3), Vector2i(2, 3), Vector2i(4, 3), Vector2i(5, 3),
			Vector2i(2, 4), Vector2i(3, 4), Vector2i(4, 4),
			Vector2i(3, 5), Vector2i(3, 6),
		]
		for p in body:
			_px(img, p.x, p.y, c)
		# Vein + stem darker.
		for vy in [2, 3, 4]:
			_px(img, 3, vy, c.darkened(0.3))
		_px(img, 3, 5, c.darkened(0.4))
		_px(img, 3, 6, c.darkened(0.4))
		_save(img, "leaf_%d.png" % i)


# --- alter portraits (ethereal "wisp" orbs with simple faces) ---

func _gen_portrait(id: String, color: Color, mouth: String) -> void:
	var img := _new_img(24, 24)
	var cx := 12
	var cy := 11
	var r := 9.0
	var light := color.lightened(0.35)
	var dark := color.darkened(0.35)
	# Body with vertical gradient + outline.
	for y in range(int(cy - r - 1), int(cy + r + 2)):
		for x in range(int(cx - r - 1), int(cx + r + 2)):
			var d: float = Vector2(x - cx, y - cy).length()
			if d <= r:
				var t: float = clampf(float(y - (cy - r)) / (2.0 * r), 0.0, 1.0)
				img.set_pixel(x, y, light.lerp(dark, t))
			elif d <= r + 1.0:
				_px(img, x, y, color.darkened(0.55))
	# Soft top highlight.
	_glow(img, cx - 3, cy - 4, 4.0, color.lightened(0.6))
	# A gentle "tail" wisp below.
	_px(img, cx, cy + 9, color.darkened(0.1))
	_px(img, cx - 1, cy + 10, color.darkened(0.2))
	_px(img, cx + 1, cy + 10, color.darkened(0.2))
	# Eyes.
	var eye := Color("#2a2030")
	for ey in [cy, cy + 1]:
		_px(img, cx - 3, ey, eye)
		_px(img, cx + 3, ey, eye)
	_px(img, cx - 3, cy - 1, eye.lerp(Color.WHITE, 0.6))   # tiny glint
	_px(img, cx + 3, cy - 1, eye.lerp(Color.WHITE, 0.6))
	# Mouth varies by role.
	var my := cy + 4
	match mouth:
		"smile":
			_px(img, cx - 2, my, eye); _px(img, cx - 1, my + 1, eye)
			_px(img, cx, my + 1, eye); _px(img, cx + 1, my + 1, eye); _px(img, cx + 2, my, eye)
		"firm":
			_px(img, cx - 2, my, eye); _px(img, cx - 1, my, eye)
			_px(img, cx, my, eye); _px(img, cx + 1, my, eye); _px(img, cx + 2, my, eye)
		"focused":
			_px(img, cx - 1, my, eye); _px(img, cx, my, eye); _px(img, cx + 1, my, eye)
			# focused brow
			_px(img, cx - 3, cy - 3, eye); _px(img, cx + 3, cy - 3, eye)
		_:  # calm
			_px(img, cx - 1, my, eye); _px(img, cx, my + 1, eye); _px(img, cx + 1, my, eye)
	_save(img, "portrait_%s.png" % id)
