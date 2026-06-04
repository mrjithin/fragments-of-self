extends Node
## Dev-only generator: procedurally builds soothing per-scene ambient pad loops with
## the AudioStreamWAV API (works headless, fully deterministic, no external files) and
## saves them as .tres under res://assets/audio/. Each scene gets a distinct chord/mood,
## kept gentle per the design doc (no jarring effects). Re-run to regenerate.
## Run: godot --headless res://tools/gen_audio.tscn

const AUDIO_DIR: String = "res://assets/audio/"
const MIX_RATE: int = 22050
const LOOP_SECS: float = 6.0           # whole clip loops seamlessly

# Per-scene mood = a soft sustained chord (Hz). Partials chosen to stay cozy/consonant.
const TRACKS := {
	"ambient_title":  [261.63, 329.63, 392.00, 493.88],   # Cmaj7  — warm welcome
	"ambient_board":  [196.00, 293.66, 440.00, 493.88],   # G add  — open, airy
	"ambient_world":  [174.61, 220.00, 261.63, 329.63],   # Fmaj7  — neutral daylight
	"ambient_mind":   [220.00, 261.63, 329.63, 392.00],   # Am7    — introspective
	"ambient_dayend": [146.83, 220.00, 293.66, 369.99],   # Dmaj   — low, resolving
	"ambient_ending": [261.63, 329.63, 493.88, 587.33],   # Cmaj9  — bright, hopeful dawn

	# Per-situation motifs. Each task gets its own chord/register so the place sounds
	# distinct from the others, while staying within the cozy/consonant palette.
	"amb_kitchen":    [261.63, 392.00, 523.25, 659.25],   # C maj, high  — bright morning
	"amb_doorstep":   [196.00, 246.94, 293.66, 392.00],   # G maj        — open, helpful
	"amb_desk":       [130.81, 196.00, 233.08, 311.13],   # C min, low   — heavy, tense bills
	"amb_hallway":    [164.81, 220.00, 246.94, 329.63],   # E min add    — small, uncertain
	"amb_threshold":  [146.83, 174.61, 220.00, 293.66],   # D min        — firm, guarded
	"amb_nightphone": [220.00, 277.18, 329.63, 415.30],   # A maj, soft  — late, worried
	"amb_nightcall":  [110.00, 164.81, 207.65, 246.94],   # A min, deep  — quiet dread/longing
	"amb_waiting":    [174.61, 261.63, 349.23, 440.00],   # F maj, airy  — sterile calm
	"amb_therapy":    [196.00, 293.66, 349.23, 440.00],   # G maj7-ish   — warm, safe
}


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(AUDIO_DIR))
	for name in TRACKS:
		var stream := _make_pad(TRACKS[name])
		var path: String = AUDIO_DIR + name + ".tres"
		var err: int = ResourceSaver.save(stream, path)
		print(("OK  " if err == OK else "FAIL %d  " % err), path)
	print("=== ambient tracks generated ===")
	get_tree().quit(0)


## Build a seamless looping 16-bit mono pad from a chord. Frequencies are snapped to
## integer cycles-per-loop so the waveform meets itself end-to-start with no click.
func _make_pad(freqs: Array) -> AudioStreamWAV:
	var frames: int = int(LOOP_SECS * MIX_RATE)
	var data := PackedByteArray()
	data.resize(frames * 2)

	var base: float = 1.0 / LOOP_SECS                 # cycle-per-loop resolution
	var snapped: Array[float] = []
	for f in freqs:
		snapped.append(maxf(base, roundf(float(f) / base) * base))
	var amp: float = 0.16                              # per-partial, sum stays < 1.0
	var trem_w: float = TAU * base                     # 1 tremolo cycle / loop (seamless)

	for i in frames:
		var t: float = float(i) / float(MIX_RATE)
		var s: float = 0.0
		for f in snapped:
			s += sin(TAU * f * t)
		s *= amp
		s *= 0.85 + 0.15 * sin(trem_w * t)             # slow breath
		var v: int = clampi(int(s * 32767.0), -32768, 32767)
		data[i * 2] = v & 0xFF
		data[i * 2 + 1] = (v >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = frames
	return stream
