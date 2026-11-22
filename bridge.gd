extends Node2D

enum Phase { INTRO, WALK, BATTLE, WIN, LOSE }

const BACKGROUND = preload("res://huajiang.png")
const INK = Color("#17292b")
const LIGHT = Color("#fff2d2")
const GOLD = Color("#ffd78a")
const MINT = Color("#a4dfb9")
const RED = Color("#ff997f")
const DECK = 291
const HERO_MAX = 24
const BOSS_MAX = 30
const BOSS_X = 737
const ACTIONS = [
	["1  出招", "造成 6 点伤害"],
	["2  吃洋芋粑", "本回合减伤，回复 4 点"],
	["3  唱山歌", "摊主接句，打断蓄力"],
]

var font := SystemFont.new()
var sfx := AudioStreamPlayer.new()
const INTRO = [
	["上一世 · 集团五十周年庆", "上一世，我白手起家，建起洋芋粑帝国，垄断了全世界的洋芋粑。", "今天集团五十周年。我上台举起一块洋芋粑：这一口，我先来。"],
	["还是上一世 · 庆典现场", "那块洋芋粑用发了芽的洋芋做的。我吃了一口，当场中毒身亡。", "集团五十周年。创始人没能撑到切蛋糕。"],
	["这一世 · 贵州花江镇", "我一睁眼，发现自己还在镇上摆摊卖洋芋粑。", "锅里滋啦响了一声。脑子里也响了一声：叮，洋芋粑系统已激活。"],
]

var phase := Phase.INTRO
var intro_page := 0
var hero_x := 130.0
var facing := 1
var met_vendor := false
var crossed := false
var hero_hp := HERO_MAX
var boss_hp := BOSS_MAX
var snacks := 0
var turn := 0
var song_used := false
var line_one := "桥那边开场了。先去摊位问问路。"
var line_two := ""
var elapsed := 0.0
var impact := 0.0
var cue := ""
var cue_color := GOLD
var step := 0

func _ready() -> void:
	font.font_names = PackedStringArray(["Microsoft YaHei UI", "Microsoft YaHei", "Noto Sans CJK SC", "PingFang SC", "WenQuanYi Micro Hei"])
	font.font_weight = 600
	add_child(sfx)

func _process(delta: float) -> void:
	elapsed += delta
	impact = maxf(0.0, impact - delta)
	if phase == Phase.WALK:
		var direction := int(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
		direction -= int(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		if direction != 0:
			facing = direction
			step = int(elapsed * 12.0) % 2
			hero_x = clampf(hero_x + direction * delta * 184.0, 42.0, 911.0 if crossed else 672.0)
		else:
			step = 0
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				get_tree().reload_current_scene()
			KEY_E, KEY_ENTER:
				_interact()
			KEY_ESCAPE:
				if phase == Phase.INTRO:
					_finish_intro()
			KEY_1:
				_act(0)
			KEY_2:
				_act(1)
			KEY_3:
				_act(2)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cursor := get_global_mouse_position()
		if phase == Phase.BATTLE:
			for index in range(ACTIONS.size()):
				if _action_rect(index).has_point(cursor):
					_act(index)
					return
		elif Rect2(746, 441, 168, 47).has_point(cursor):
			_interact()

func _interact() -> void:
	if phase == Phase.INTRO:
		_advance_intro()
		return
	if phase == Phase.LOSE:
		get_tree().reload_current_scene()
		return
	if phase == Phase.WIN:
		phase = Phase.WALK
		crossed = true
		line_one = "嬢嬢：过了桥记得回来收摊！"
		line_two = "主角：晓得了！下次我把前半句也唱准。"
		return
	if phase != Phase.WALK:
		return
	if hero_x >= 116.0 and hero_x <= 310.0 and not met_vendor:
		met_vendor = true
		snacks = 2
		line_one = "嬢嬢：摊我帮你看。锅里刚煎好两个，拿去桥上垫垫肚子。"
		line_two = "系统：洋芋粑 +2。  嬢嬢：桥头要是考山歌，后半句我接。"
		_sound(440.0, 660.0, 0.18)
	elif hero_x >= 610.0 and not crossed:
		phase = Phase.BATTLE
		hero_x = 545.0
		facing = 1
		line_one = "山歌裁判：过桥先过我这一关！"
		line_two = "主角：早知道就从桥底游过去了。"
		_sound(240.0, 150.0, 0.22)
	elif crossed and hero_x >= 815.0:
		line_one = "系统：赶集开张任务完成。桥对面的灯亮了。"
		line_two = "试着按 R 重开，看看能不能换一种打法。"
	else:
		line_one = "往前走，到洋芋粑摊或桥头再按 E。"
		line_two = ""


func _advance_intro() -> void:
	if intro_page == INTRO.size() - 1:
		_finish_intro()
		return
	intro_page += 1
	elapsed = 0.0
	if intro_page == 1:
		_sound(260.0, 80.0, 0.45)
	else:
		_sound(330.0, 660.0, 0.3)

func _finish_intro() -> void:
	phase = Phase.WALK
	elapsed = 0.0
	line_one = "你醒在花江镇自己的洋芋粑摊前。锅还热着。"
	line_two = "系统任务：请隔壁嬢嬢帮忙看摊，再去桥头赶场。"

func _draw_intro() -> void:
	if intro_page == 2:
		draw_texture_rect(BACKGROUND, Rect2(0, 0, 960, 540), false)
		_rect(0, 0, 960, 345, Color("#13272666"))
		_stall()
		_person(hero_x, DECK, Color("#4d8e92"), Color("#34494e"), 1, false, 0)
		_rect(495, 83, 392, 140, INK)
		_rect(495, 83, 4, 140, MINT)
		_type("洋芋粑系统  ·  已激活", 518, 120, 19, MINT)
		_type("身份：镇上摆摊卖洋芋粑的", 518, 156, 17)
		_type("新手任务：赶集开张", 518, 188, 17, GOLD)
	else:
		var poisoned := intro_page == 1
		_rect(0, 0, 960, 540, Color("#18252d") if poisoned else Color("#3e242b"))
		_rect(0, 244, 960, 109, Color("#241b26"))
		_rect(0, 244, 960, 4, Color("#ad6752"))
		for column in range(7):
			_rect(60 + column * 140, 58, 3, 130, Color("#663740"))
			draw_circle(Vector2(60 + column * 140, 55), 3, GOLD)
		draw_circle(Vector2(480, 181), 104, Color("#f2be7144"))
		draw_circle(Vector2(480, 181), 87, Color("#a85b43"))
		draw_circle(Vector2(480, 181), 81, Color("#e9c293"))
		draw_circle(Vector2(480, 181), 63, Color("#553c3a"))
		draw_rect(Rect2(438, 163, 84, 36), Color("#bf733c"))
		draw_rect(Rect2(444, 159, 72, 35), Color("#ebb363"))
		draw_rect(Rect2(448, 164, 64, 18), Color("#f6cd7f"))
		for crumb in range(9):
			_rect(450 + crumb * 7, 174 + (crumb % 3) * 5, 3, 3, Color("#ce8143"))
		if poisoned:
			_rect(490, 150, 6, 17, Color("#8aab58"))
			_rect(495, 149, 9, 5, Color("#a6cd65"))
			var fade := clampf(elapsed * 0.3, 0.0, 0.6)
			_rect(0, 0, 960, 344, Color(0.05, 0.07, 0.09, fade))
		else:
			_type("洋芋粑帝国", 79, 137, 31, GOLD)
			_type("集团成立五十周年", 79, 176, 23)
			_type("50", 733, 183, 92, GOLD)

	var card: Array = INTRO[intro_page]
	_rect(26, 345, 908, 170, Color("#192b2bf5"))
	_rect(26, 345, 908, 2, GOLD)
	_type(card[0], 46, 379, 20, GOLD)
	_type(card[1], 46, 413, 19)
	_type(card[2], 46, 444, 17, MINT)
	_type("Esc 跳过序章", 46, 490, 14, GOLD)
	_button_frame(Rect2(746, 441, 168, 47), true)
	_type("E  继续" if intro_page < 2 else "E  开始摆摊", 763, 472, 18)

func _charging() -> bool:
	return turn % 3 != 1

func _available(action: int) -> bool:
	return (action != 1 or snacks > 0) and (action != 2 or (met_vendor and not song_used))

func _act(action: int) -> void:
	if phase != Phase.BATTLE:
		return
	if not _available(action):
		line_two = "洋芋粑吃完了。" if action == 1 else "这一架只能请摊主接一次山歌。"
		return
	var heavy := _charging()
	var hit := 10 if heavy else 4
	match action:
		0:
			boss_hp -= 6
			line_one = "主角上前敲了一记。裁判扣了 6 点气势。"
			cue = "−6"
			cue_color = RED
			_sound(320.0, 110.0, 0.14)
		1:
			snacks -= 1
			hero_hp = mini(HERO_MAX, hero_hp + 4)
			hit = maxi(0, hit - 8)
			line_one = "主角嚼完才抬头：你打完了？"
			cue = "稳住！"
			cue_color = GOLD
			_sound(190.0, 370.0, 0.16)
		2:
			song_used = true
			boss_hp -= 12 if heavy else 6
			line_one = "主角开口跑调。桥底下，摊主稳稳接住了下句。"
			cue = "打断！" if heavy else "有人接歌！"
			cue_color = MINT
			if heavy:
				hit = 0
			_sound(392.0, 587.0, 0.38)
	impact = 0.5
	if boss_hp <= 0:
		boss_hp = 0
		phase = Phase.WIN
		line_two = "裁判：过、过。你俩一个跑调，一个还敢接。"
		return
	hero_hp = maxi(0, hero_hp - hit)
	line_two = "裁判的招被化解了。" if hit == 0 else "裁判还手，你掉了 %d 点体力。" % hit
	if hero_hp == 0:
		phase = Phase.LOSE
		line_two = "裁判：去摊上吃饱了再来。我在桥头等你。"
	turn += 1

func _sound(start_hz: float, end_hz: float, length: float) -> void:
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

func _meter(x: float, y: float, current: int, maximum: int, color: Color) -> void:
	_rect(x, y, 186, 7, Color("#47534f"))
	_rect(x, y, roundf(186.0 * current / maximum), 7, color)

func _stall() -> void:
	_person(186, 268, Color("#aa5d4d"), Color("#df9c57"), 1, false, 0)
	_rect(162, 253, 117, 40, Color("#653e31"))
	_rect(163, 249, 116, 7, Color("#ffc078"))
	for i in range(6):
		_rect(158 + i * 21, 212, 21, 15, Color("#c75a4c") if i % 2 == 0 else Color("#f8c783"))
	_rect(158, 227, 126, 4, INK)
	_rect(165, 231, 4, 19, Color("#7e4e38"))
	_rect(275, 231, 4, 19, Color("#7e4e38"))
	_rect(184, 188, 73, 25, INK)
	_type("洋芋粑", 198, 206, 15, GOLD)
	_rect(205, 242, 54, 7, INK)
	for i in range(3):
		_rect(209 + i * 16, 238, 12, 6, GOLD)
		var drift := fmod(elapsed * 20.0 + i * 11.0, 34.0)
		_rect(214 + i * 16 + roundf(sin(drift * 0.19) * 3.0), 239 - drift, 3, 3, Color(1.0, 0.95, 0.87, 1.0 - drift / 34.0))

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

func _action_rect(action: int) -> Rect2:
	return Rect2(46 + action * 293, 437, 280, 64)

func _button_frame(box: Rect2, enabled: bool) -> void:
	var hover := enabled and box.has_point(get_global_mouse_position())
	draw_rect(box, Color("#3d5c55") if hover else Color("#29423e"))
	draw_rect(box, GOLD if hover else Color("#57695e"), false, 1)

func _draw() -> void:
	if phase == Phase.INTRO:
		_draw_intro()
		return
	draw_texture_rect(BACKGROUND, Rect2(0, 0, 960, 540), false)
	_rect(0, DECK, 960, 11, Color("#522e29"))
	_rect(0, DECK, 960, 3, Color("#f2b278"))
	for column in range(32):
		_rect(column * 30, DECK + 4, 29, 3, Color("#a95a46"))
	_stall()
	if crossed:
		_rect(835, 232, 70, 27, INK)
		_rect(838, 234, 64, 2, GOLD)
		_type("集市", 855, 252, 16, GOLD)
	_person(hero_x, DECK, Color("#4d8e92"), Color("#34494e"), facing, false, step)
	if not crossed:
		_person(BOSS_X, DECK, Color("#be5951"), Color("#633957"), -1, true, 0)
		if phase == Phase.BATTLE and _charging():
			var glow := 0.5 + sin(elapsed * 6.0) * 0.24
			draw_circle(Vector2(BOSS_X - 16, DECK - 30), 5.0, Color(1.0, 0.69, 0.36, glow))
	if impact > 0.0:
		_type(cue, BOSS_X - 26, DECK - 65 - (0.5 - impact) * 32.0, 25, cue_color)

	_rect(26, 24, 270, 77, INK)
	_rect(26, 24, 5, 77, GOLD)
	_type("贵州 · 花江峡谷", 46, 52, 17, GOLD)
	_type("过桥赶场", 46, 84, 29)

	if phase == Phase.BATTLE:
		_rect(340, 24, 594, 77, INK)
		_type("你  %d / %d" % [hero_hp, HERO_MAX], 364, 52, 17)
		_meter(364, 72, hero_hp, HERO_MAX, MINT)
		_type("裁判  %d / %d" % [boss_hp, BOSS_MAX], 714, 52, 17)
		_meter(714, 72, boss_hp, BOSS_MAX, RED)
		_rect(626, 144, 285, 36, INK)
		_type("裁判蓄力 · 重击" if _charging() else "裁判试探 · 轻击", 644, 168, 17, GOLD if _charging() else LIGHT)
	elif phase == Phase.WALK:
		var target_x := 211.0 if not met_vendor else (870.0 if crossed else 653.0)
		var prompt := "去摊位" if not met_vendor else ("去集市" if crossed else "去桥头")
		_type("▼  " + prompt, target_x - 28.0, 180.0 + sin(elapsed * 3.0) * 3.0, 15, GOLD)

	_rect(26, 349, 908, 166, Color("#192b2bee"))
	_rect(26, 349, 908, 2, GOLD)
	_type(line_one, 46, 385, 21)
	if not line_two.is_empty():
		_type(line_two, 46, 415, 17, MINT)

	if phase == Phase.BATTLE:
		for index in range(ACTIONS.size()):
			var box := _action_rect(index)
			var enabled := _available(index)
			_button_frame(box, enabled)
			var detail: String = ACTIONS[index][1]
			if index == 1:
				detail = "%s · 剩 %d 个" % [detail, snacks]
			elif index == 2 and not enabled:
				detail = "已用过" if song_used else "先和摊主打个招呼"
			_type(ACTIONS[index][0], box.position.x + 14, 463, 19, LIGHT if enabled else Color("#a1aca3"))
			_type(detail, box.position.x + 14, 487, 14, GOLD if enabled else Color("#a1aca3"))
	else:
		_type("A / D 或 ← / → 移动     ·     E 互动     ·     R 重开", 46, 475, 15, GOLD)
		_button_frame(Rect2(746, 441, 168, 47), true)
		var prompt := "E  继续"
		match phase:
			Phase.WALK:
				prompt = "E  互动"
			Phase.LOSE:
				prompt = "E  再来一次"
		_type(prompt, 763, 472, 18)
