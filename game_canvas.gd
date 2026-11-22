extends Node2D

const INK = Color("#17292b")
const LIGHT = Color("#fff2d2")
const GOLD = Color("#ffd78a")
const MINT = Color("#a4dfb9")
const RED = Color("#ff997f")

var font := SystemFont.new()
var sfx := AudioStreamPlayer.new()

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "PingFang SC", "WenQuanYi Micro Hei"])
	font.font_weight = 600
	add_child(sfx)

func _sound(start_hz: float, end_hz: float, length: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	const RATE = 22050
	var count := int(length * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var angle := 0.0
	for sample in range(count):
		var fraction := float(sample) / count
		var envelope := minf(1.0, 50.0 * fraction) * pow(1.0 - fraction, 1.5)
		angle += TAU * lerpf(start_hz, end_hz, fraction) / RATE
		var wave := (sin(angle) + 0.24 * sin(2.0 * angle)) * envelope
		data.encode_s16(sample * 2, int(wave * 6900))
	var clip := AudioStreamWAV.new()
	clip.format = AudioStreamWAV.FORMAT_16_BITS
	clip.mix_rate = RATE
	clip.data = data
	sfx.stream = clip
	sfx.play()

func _rect(x: float, y: float, w: float, h: float, color: Color) -> void:
	draw_rect(Rect2(x, y, w, h), color)

func _type(value: String, x: float, y: float, size: int, color: Color = LIGHT) -> void:
	draw_string(font, Vector2(x, y), value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _meter(x: float, y: float, current: int, maximum: int, color: Color, width: float = 186.0) -> void:
	_rect(x, y, width, 7, Color("#47534f"))
	_rect(x, y, roundf(width * current / maximum), 7, color)

func _person(x: float, baseline: float, jacket: Color, hat: Color, side: int, large: bool, gait: int) -> void:
	var scale_px := 3 if large else 2
	var y := baseline - gait * 2
	draw_ellipse_shadow(x, baseline)
	var marks := [
		[0, -17, 10, 6, INK], [1, -16, 8, 4, hat], [-2, -13, 14, 2, INK],
		[0, -11, 10, 5, Color("#f2b581")], [5 + side * 2, -10, 2, 2, INK],
		[-1, -6, 12, 5, INK], [0, -6, 10, 4, jacket], [4, -6, 2, 4, GOLD],
		[0, -2, 4, 2 + gait, INK], [6, -2, 4, 3 - gait, INK],
	]
	for mark in marks:
		_rect(roundf(x - 5 * scale_px + mark[0] * scale_px),
			roundf(y + mark[1] * scale_px), mark[2] * scale_px, mark[3] * scale_px, mark[4])

func draw_ellipse_shadow(x: float, y: float) -> void:
	draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 22, Color(0.06, 0.12, 0.12, 0.56))
	draw_set_transform(Vector2.ZERO)

func _button_frame(box: Rect2, enabled: bool) -> void:
	var hover := enabled and box.has_point(get_global_mouse_position())
	draw_rect(box, Color("#3d5c55") if hover else Color("#29423e"))
	draw_rect(box, GOLD if hover else Color("#57695e"), false, 1)
