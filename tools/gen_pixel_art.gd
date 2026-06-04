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
	_gen_board_bg()
	_gen_dayend_bg()
	_gen_ending_bg()
	_gen_situation_bgs()
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


## Task board: a cozy interior hub — warm room, a window onto the autumn evening,
## and a corkboard of pinned notes. Reads as "indoors, planning the day" — distinct
## from the open-air External World it used to borrow.
func _gen_board_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	# Warm room wall: soft amber, a touch darker toward the top.
	var wall_top := Color("#4a3526")
	var wall_bot := Color("#6e4d34")
	for y in BG_H:
		var t: float = float(y) / float(BG_H)
		var row: Color = wall_top.lerp(wall_bot, pow(t, 0.7))
		for x in BG_W:
			img.set_pixel(x, y, row)
	# Floor band along the bottom.
	for y in range(150, BG_H):
		for x in BG_W:
			img.set_pixel(x, y, Color("#3a281c"))
	# A window on the right looking out at dusk.
	var wx0: int = 214
	var wy0: int = 30
	var ww: int = 78
	var wh: int = 72
	for y in range(wy0, wy0 + wh):
		for x in range(wx0, wx0 + ww):
			var t: float = float(y - wy0) / float(wh)
			img.set_pixel(x, y, Color("#7a6a96").lerp(Color("#e0a276"), pow(t, 0.9)))
	_glow(img, wx0 + 56, wy0 + 22, 16.0, Color("#ffe6b0"))   # low sun outside
	# Window frame + mullions.
	var frame := Color("#2c1d14")
	for x in range(wx0 - 2, wx0 + ww + 2):
		_px(img, x, wy0 - 2, frame); _px(img, x, wy0 - 1, frame)
		_px(img, x, wy0 + wh, frame); _px(img, x, wy0 + wh + 1, frame)
	for y in range(wy0 - 2, wy0 + wh + 2):
		_px(img, wx0 - 2, y, frame); _px(img, wx0 - 1, y, frame)
		_px(img, wx0 + ww, y, frame); _px(img, wx0 + ww + 1, y, frame)
		_px(img, wx0 + ww / 2, y, frame)
	for x in range(wx0, wx0 + ww):
		_px(img, x, wy0 + wh / 2, frame)
	# Corkboard on the left with a few pinned notes.
	var bx0: int = 24
	var by0: int = 40
	var bw: int = 110
	var bh: int = 78
	for y in range(by0, by0 + bh):
		for x in range(bx0, bx0 + bw):
			img.set_pixel(x, y, Color("#9c6e3f"))
	for x in range(bx0 - 2, bx0 + bw + 2):
		_px(img, x, by0 - 2, frame); _px(img, x, by0 + bh + 1, frame)
	for y in range(by0 - 2, by0 + bh + 2):
		_px(img, bx0 - 2, y, frame); _px(img, bx0 + bw + 1, y, frame)
	var notes := [
		{"x": 34, "y": 50, "c": Color("#e8dcc0")},
		{"x": 78, "y": 58, "c": Color("#d9c79e")},
		{"x": 50, "y": 86, "c": Color("#ece3cd")},
	]
	for n in notes:
		var nx: int = n["x"]
		var ny: int = n["y"]
		for y in range(ny, ny + 24):
			for x in range(nx, nx + 30):
				img.set_pixel(x, y, n["c"])
		# scribbled lines + a pin
		for li in [6, 12, 18]:
			for x in range(nx + 4, nx + 26):
				_blend(img, x, ny + li, Color("#5a4a36"), 0.55)
		_disc(img, nx + 15, ny - 1, 2.0, Color("#b8482f"))
	# A warm desk lamp glow in the lower-left corner.
	_glow(img, 30, 150, 40.0, Color("#ffcf86"))
	_save(img, "bg_board.png")


## Day-end: dusk falling — low, resolving, a little darker per the design's "occasional
## darker tones". Deep evening sky, first stars, dark hills, a small steady ember of warmth.
func _gen_dayend_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	var top := Color("#1b1830")
	var bot := Color("#6b4258")
	for y in BG_H:
		var t: float = float(y) / float(BG_H)
		var row: Color = top.lerp(bot, pow(t, 1.3))
		for x in BG_W:
			img.set_pixel(x, y, row)
	# Emerging stars (upper sky only).
	var seed_val: int = 4242
	for i in 55:
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var x: int = seed_val % BG_W
		seed_val = (seed_val * 1103515245 + 12345) & 0x7fffffff
		var y: int = seed_val % 100
		_blend(img, x, y, Color("#e9e3ff"), 0.35 + 0.45 * float(seed_val % 100) / 100.0)
	# A faint band of last light at the horizon.
	for y in range(108, 124):
		for x in BG_W:
			var t: float = 1.0 - float(y - 108) / 16.0
			_blend(img, x, y, Color("#d68a5a"), 0.4 * t)
	# Two layers of dark hills.
	var layers := [
		{"base": 122, "amp": 9.0, "freq": 0.02, "phase": 0.6, "color": Color("#241a2e")},
		{"base": 140, "amp": 12.0, "freq": 0.028, "phase": 3.0, "color": Color("#16101c")},
	]
	for layer in layers:
		for x in BG_W:
			var hy: int = int(layer["base"] - layer["amp"] * sin(x * layer["freq"] + layer["phase"]))
			for y in range(hy, BG_H):
				img.set_pixel(x, y, layer["color"])
	# A small ember of warmth on the front hill (a window light far off).
	_glow(img, 96, 150, 9.0, Color("#ffb86a"))
	_px(img, 96, 150, Color("#ffe1ad"))
	_save(img, "bg_dayend.png")


## Ending: dawn — the payoff. Hopeful sunrise, warm gold over the hills, soft rays.
## Reads as resolution/new morning, clearly apart from the night title screen.
func _gen_ending_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	var top := Color("#3a4a78")
	var bot := Color("#f2c27a")
	for y in BG_H:
		var t: float = float(y) / float(BG_H)
		var row: Color = top.lerp(bot, pow(t, 1.4))
		for x in BG_W:
			img.set_pixel(x, y, row)
	# Rising sun low on the horizon, with a broad glow.
	var sun := Vector2(160, 118)
	_glow(img, int(sun.x), int(sun.y), 70.0, Color("#ffe6a8"))
	_glow(img, int(sun.x), int(sun.y), 34.0, Color("#fff0c4"))
	_disc(img, int(sun.x), int(sun.y), 20.0, Color("#fff6da"))
	# Soft diagonal light rays fanning up from the sun.
	for k in range(-4, 5):
		var ang: float = float(k) * 0.16
		for r in range(20, 150):
			var x: int = int(sun.x + sin(ang) * r)
			var y: int = int(sun.y - cos(ang) * r * 0.9)
			_blend(img, x, y, Color("#fff2c8"), 0.06)
	# Gentle hills catching the morning light (front darker).
	var layers := [
		{"base": 132, "amp": 8.0, "freq": 0.019, "phase": 1.2, "color": Color("#caa05e")},
		{"base": 150, "amp": 11.0, "freq": 0.026, "phase": 3.7, "color": Color("#8f6a3c")},
		{"base": 166, "amp": 9.0, "freq": 0.033, "phase": 5.5, "color": Color("#5e4528")},
	]
	for layer in layers:
		for x in BG_W:
			var hy: int = int(layer["base"] - layer["amp"] * sin(x * layer["freq"] + layer["phase"]))
			for y in range(hy, BG_H):
				img.set_pixel(x, y, layer["color"])
	_save(img, "bg_ending.png")


# --- per-situation backgrounds ---
# Shared blocky helpers so each room stays consistent in style but distinct in place.

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


func _fill(img: Image, top: Color, bot: Color) -> void:
	_vgrad(img, 0, 0, BG_W, BG_H, top, bot)


func _frame(img: Image, x0: int, y0: int, w: int, h: int, c: Color, th: int = 2) -> void:
	for t in range(th):
		for x in range(x0 - t, x0 + w + t):
			_px(img, x, y0 - 1 - t, c)
			_px(img, x, y0 + h + t, c)
		for y in range(y0 - t, y0 + h + t):
			_px(img, x0 - 1 - t, y, c)
			_px(img, x0 + w + t, y, c)


func _gen_situation_bgs() -> void:
	_gen_kitchen_bg()
	_gen_doorstep_bg()
	_gen_desk_bg()
	_gen_hallway_bg()
	_gen_threshold_bg()
	_gen_nightphone_bg()
	_gen_nightcall_bg()
	_gen_waiting_bg()
	_gen_therapy_bg()


## job_interview — a kitchen at morning, an opened letter on the table.
func _gen_kitchen_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	_fill(img, Color("#caa56e"), Color("#a9824f"))
	# Window of bright morning light, right side.
	_vgrad(img, 206, 26, 86, 78, Color("#bfd2e6"), Color("#fbe3a6"))
	_glow(img, 250, 44, 22.0, Color("#fff3c8"))
	_frame(img, 206, 26, 86, 78, Color("#5a3c26"))
	for y in range(26, 104):
		_px(img, 249, y, Color("#5a3c26"))
	for x in range(206, 292):
		_px(img, x, 65, Color("#5a3c26"))
	# Counter/table band across the lower third.
	_rect(img, 0, 120, BG_W, 60, Color("#7a5333"))
	_rect(img, 0, 120, BG_W, 5, Color("#8f6440"))
	# A plate + the opened letter on the table.
	_disc(img, 96, 142, 13.0, Color("#e7ddcb"))
	_disc(img, 96, 142, 9.0, Color("#d8cbb2"))
	_rect(img, 150, 132, 46, 30, Color("#efe7d4"))   # letter
	for li in [8, 14, 20]:
		for x in range(154, 192):
			_blend(img, x, 132 + li, Color("#6a5a44"), 0.5)
	# A mug, steaming.
	_rect(img, 230, 134, 16, 18, Color("#9c4f3a"))
	for x in [236, 240]:
		_blend(img, x, 128, Color("#fff", 0), 0.0)
	_save(img, "bg_kitchen.png")


## neighbour_help — a doorway onto daylight, stacked moving boxes.
func _gen_doorstep_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	_fill(img, Color("#caa07a"), Color("#9c7a5b"))   # interior wall, warm
	# Open door on the left showing bright outdoors.
	_vgrad(img, 18, 24, 96, 140, Color("#acd0e0"), Color("#dcecc0"))
	_glow(img, 60, 50, 30.0, Color("#fdf3cf"))
	_rect(img, 18, 150, 96, 14, Color("#7e9a5e"))    # grass strip outside
	_frame(img, 18, 24, 96, 140, Color("#4a3324"), 3)
	# Floor.
	_rect(img, 0, 150, BG_W, 30, Color("#6e4d33"))
	# Stacked cardboard boxes on the right.
	var box := Color("#b98a52")
	var box_d := Color("#8f6238")
	for b in [[176, 110, 52, 50], [232, 96, 56, 64], [196, 60, 48, 48]]:
		var bx: int = b[0]
		var by: int = b[1]
		_rect(img, bx, by, b[2], b[3], box)
		_frame(img, bx, by, b[2], b[3], box_d, 1)
		# tape line
		_rect(img, bx, by + b[3] / 2 - 2, b[2], 4, box_d)
	_save(img, "bg_doorstep.png")


## overdue_bills — a dim desk, a red-stamped envelope, a lamp's pool of light.
func _gen_desk_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	_fill(img, Color("#2e2630"), Color("#43342f"))
	# Lamp glow from upper-left.
	_glow(img, 54, 30, 70.0, Color("#e9b96a"))
	_disc(img, 54, 22, 8.0, Color("#ffd98a"))
	# Desk surface.
	_rect(img, 0, 118, BG_W, 62, Color("#4a3322"))
	_rect(img, 0, 118, BG_W, 5, Color("#5e422c"))
	# Stack of papers + the red-stamped envelope.
	_rect(img, 70, 128, 60, 40, Color("#d8cdb6"))
	_rect(img, 76, 122, 60, 40, Color("#e7ddc8"))
	_rect(img, 150, 130, 70, 34, Color("#e4d9c2"))   # envelope
	_frame(img, 150, 130, 70, 34, Color("#b0a384"), 1)
	_rect(img, 196, 134, 16, 12, Color("#b23a2c"))   # red stamp
	_save(img, "bg_desk.png")


## calm_the_child — an apartment hallway, a row of doors, low light.
func _gen_hallway_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	_fill(img, Color("#534056"), Color("#6e5346"))
	# Receding side walls (darker) framing a lit far wall.
	for x in BG_W:
		var edge: float = abs(float(x) - 160.0) / 160.0    # 0 center -> 1 edges
		for y in range(0, 150):
			var c: Color = img.get_pixel(x, y)
			_px(img, x, y, c.darkened(0.45 * edge))
	# Floor runner.
	_rect(img, 0, 150, BG_W, 30, Color("#3e2c33"))
	_rect(img, 120, 150, 80, 30, Color("#5a3f48"))
	# A few doors along the hall.
	for dx in [40, 132, 224]:
		_rect(img, dx, 70, 40, 80, Color("#7a5a44"))
		_frame(img, dx, 70, 40, 80, Color("#2e2026"), 1)
		_disc(img, dx + 34, 112, 1.5, Color("#e7c878"))   # handle
	# A soft ceiling light over the middle door.
	_glow(img, 152, 64, 26.0, Color("#f2d79a"))
	_save(img, "bg_hallway.png")


## stand_ground — a threshold at dusk, a firm doorframe, a figure's silhouette outside.
func _gen_threshold_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	_fill(img, Color("#2a2336"), Color("#5a3f49"))   # dim interior
	# Doorway opening onto a dusk sky.
	_vgrad(img, 104, 20, 112, 150, Color("#5b4f7e"), Color("#d98a64"))
	_glow(img, 160, 120, 26.0, Color("#f1b070"))
	# A standing silhouette in the doorway (the acquaintance).
	_disc(img, 160, 84, 12.0, Color("#1c1722"))
	_rect(img, 148, 96, 24, 60, Color("#1c1722"))
	_frame(img, 104, 20, 112, 150, Color("#241a24"), 4)
	_rect(img, 0, 156, BG_W, 24, Color("#241a26"))   # interior floor
	_save(img, "bg_threshold.png")


## friend_crisis — evening room, a phone buzzing on the table, its screen glowing.
func _gen_nightphone_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	_fill(img, Color("#1d2238"), Color("#33304a"))
	# Night window.
	_vgrad(img, 30, 26, 80, 70, Color("#0e1326"), Color("#26203a"))
	_frame(img, 30, 26, 80, 70, Color("#2c2740"))
	for x in range(30, 110):
		_px(img, x, 61, Color("#2c2740"))
	for y in range(26, 96):
		_px(img, 70, y, Color("#2c2740"))
	# Table + the phone with a cold glow.
	_rect(img, 0, 124, BG_W, 56, Color("#2b2336"))
	_glow(img, 190, 132, 26.0, Color("#7fa6d8"))
	_rect(img, 178, 124, 24, 16, Color("#101524"))
	_rect(img, 181, 126, 18, 12, Color("#9cc4f0"))   # screen
	_save(img, "bg_nightphone.png")


## hard_conversation — deep night, a single warm lamp, a voicemail's quiet weight.
func _gen_nightcall_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	_fill(img, Color("#141426"), Color("#241f33"))
	# Single warm lamp, lower-right, carving a small pool of light.
	_glow(img, 236, 96, 78.0, Color("#d99a58"))
	_glow(img, 236, 96, 30.0, Color("#f3c483"))
	_disc(img, 236, 78, 7.0, Color("#ffe0a0"))
	_rect(img, 232, 96, 8, 40, Color("#3a2c22"))     # lamp stem
	# Floor/table edge catching the light.
	_rect(img, 0, 150, BG_W, 30, Color("#1c1828"))
	for x in range(150, BG_W):
		_blend(img, x, 150, Color("#e0a868"), 0.3 * (float(x - 150) / 170.0))
	_save(img, "bg_nightcall.png")


## the_appointment — a clinic waiting room, pale and quiet, chairs and a named door.
func _gen_waiting_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	_fill(img, Color("#9fb0a6"), Color("#c2c9bc"))   # cool, pale, clinical
	# Floor.
	_rect(img, 0, 140, BG_W, 40, Color("#b8a98c"))
	# A door with a name plate, centre-right.
	_rect(img, 196, 44, 56, 96, Color("#d8d2c4"))
	_frame(img, 196, 44, 56, 96, Color("#8a8576"), 2)
	_rect(img, 206, 60, 36, 10, Color("#e9e4d6"))    # name plate
	_disc(img, 244, 94, 1.6, Color("#7a756a"))
	# A row of waiting chairs along the left.
	for cx in [24, 70, 116]:
		_rect(img, cx, 110, 34, 22, Color("#6f8f9c"))   # seat
		_rect(img, cx, 92, 34, 20, Color("#5e7d8a"))    # back
	# A potted plant by the door.
	_rect(img, 170, 120, 14, 20, Color("#7a5236"))
	_disc(img, 177, 110, 10.0, Color("#5e8a52"))
	_save(img, "bg_waiting.png")


## the_telling — a warm therapy room, two chairs facing, a rug: safety, resolution.
func _gen_therapy_bg() -> void:
	var img := _new_img(BG_W, BG_H)
	_fill(img, Color("#6e4f48"), Color("#8a6450"))   # warm, cozy
	# Soft lamp glow upper-right.
	_glow(img, 270, 36, 56.0, Color("#f1c884"))
	# Floor + a centred rug.
	_rect(img, 0, 140, BG_W, 40, Color("#5a3e34"))
	_rect(img, 96, 150, 128, 26, Color("#a85a44"))
	_frame(img, 96, 150, 128, 26, Color("#c98a5e"), 1)
	# Two armchairs facing each other.
	_rect(img, 40, 104, 50, 40, Color("#7c5a8c"))    # left chair seat/back
	_rect(img, 40, 96, 50, 14, Color("#6c4a7c"))
	_rect(img, 230, 104, 50, 40, Color("#6f9a7b"))   # right chair
	_rect(img, 230, 96, 50, 14, Color("#5e8a6b"))
	# A small plant between them, in the warm light.
	_rect(img, 156, 120, 10, 16, Color("#5a3a2c"))
	_disc(img, 161, 112, 9.0, Color("#6aa05c"))
	_save(img, "bg_therapy.png")


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
