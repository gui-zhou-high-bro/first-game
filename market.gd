extends Node2D

enum Phase { INTRO, WALK, BATTLE, WIN, LOSE }

const BACKGROUND = preload("res://art/town-market.png")
const FIRST_PERSON = preload("res://art/xiaohui-pov.png")
const MARKET_CROWD = preload("res://art/market-crowd.ogg")
const INK = Color("#17292b")
const LIGHT = Color("#fff2d2")
const GOLD = Color("#ffd78a")
const MINT = Color("#a4dfb9")
const RED = Color("#ff997f")
const STREET = 374
const HERO_MAX = 24
const BOSS_MAX = 30
const BOSS_X = 737
const ACTIONS = [
	["1  出招", "造成 6 点伤害"],
	["2  吃洋芋粑", "本回合减伤，回复 4 点"],
	["3  唱山歌", "小惠接句，打断蓄力"],
]

var font := SystemFont.new()
var sfx := AudioStreamPlayer.new()
var crowd := AudioStreamPlayer.new()
const INTRO = [
	["小惠", "醒啦？你守着锅都能睡着。再不翻面，洋芋粑要煎成锅巴咯。", "我一睁眼，青梅竹马小惠正俯身看着我。隔着水泥路，对面摊贩正吆喝。"],
	["我", "小惠？我不是在集团五十周年庆上，吃了发芽洋芋做的粑粑就……", "上一世，我垄断了全世界的洋芋粑。这一世，我还在镇上守着自己的小摊。"],
	["洋芋粑系统", "叮！洋芋粑系统已激活。新手任务：在镇上把摊子开起来。", "小惠：嘀咕啥呢？你先翻面。超市门口今天还有人摆擂台。"],
]

var phase := Phase.INTRO
var intro_page := 0
var hero_x := 130.0
var facing := 1
var talked_to_xiaohui := false
var won_match := false
var hero_hp := HERO_MAX
var boss_hp := BOSS_MAX
var snacks := 0
var turn := 0
var song_used := false
var line_one := ""
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
	var ambiance := MARKET_CROWD.duplicate() as AudioStreamOggVorbis
	ambiance.loop = true
	crowd.stream = ambiance
	crowd.volume_db = -11.0
	add_child(crowd)
	if DisplayServer.get_name() != "headless":
		crowd.play()

func _process(delta: float) -> void:
	elapsed += delta
	impact = maxf(0.0, impact - delta)
	if phase == Phase.WALK:
		var direction := int(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
		direction -= int(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		if direction != 0:
			facing = direction
			step = int(elapsed * 12.0) % 2
			hero_x = clampf(hero_x + direction * delta * 184.0, 42.0, 911.0 if won_match else 672.0)
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
		won_match = true
		line_one = "小惠：打完啦？回来帮忙，锅里下一批都快好了。"
		line_two = "主角：晓得了！下次我把前半句也唱准。"
		return
	if phase != Phase.WALK:
		return
	if hero_x >= 116.0 and hero_x <= 310.0 and not talked_to_xiaohui:
		talked_to_xiaohui = true
		snacks = 2
		line_one = "小惠：这两个先留给你。超市门口有人摆擂，赢了给摊子招揽点客人。"
		line_two = "系统：洋芋粑 +2。  小惠：要是考山歌，后半句我接。"
		_sound(440.0, 660.0, 0.18)
	elif hero_x >= 610.0 and not won_match:
		phase = Phase.BATTLE
		hero_x = 545.0
		facing = 1
		line_one = "山歌裁判：超市门口比山歌！你这个卖粑粑的，也来试试？"
		line_two = "主角：试就试。先说好，洋芋粑不当赌注。"
		_sound(240.0, 150.0, 0.22)
	elif won_match and hero_x >= 815.0:
		line_one = "系统：赶集开张任务完成。街坊开始往你的摊子排队了。"
		line_two = "试着按 R 重开，看看能不能换一种打法。"
	else:
		line_one = "在洋芋粑摊前找小惠，或到超市门口按 E。"
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
	line_one = "你回过神，锅里的洋芋粑还滋啦响。小惠敲了敲你的锅铲。"
	line_two = "系统任务：和小惠说话，去超市门口看看。"

func _draw_intro() -> void:
	draw_texture_rect(FIRST_PERSON, Rect2(0, 0, 960, 540), false)
	var eyelid := 270.0 * (1.0 - smoothstep(0.0, 0.68, elapsed))
	if intro_page == 0 and eyelid > 0.0:
		_rect(0, 0, 960, eyelid, Color("#171416"))
		_rect(0, 540 - eyelid, 960, eyelid, Color("#171416"))

	var card: Array = INTRO[intro_page]
	_rect(26, 20, 126, 31, INK)
	_type("贵州 · 赶场日", 39, 41, 15, GOLD)
	_rect(26, 388, 908, 127, Color("#192b2bf2"))
	_rect(26, 388, 908, 2, GOLD)
	_type(card[0], 46, 418, 20, GOLD)
	_type(card[1], 46, 447, 18)
	_type(card[2], 46, 476, 16, MINT)
	_type("Esc 跳过序章", 46, 502, 13, GOLD)
	_button_frame(Rect2(746, 441, 168, 47), true)
	_type("E  继续" if intro_page < INTRO.size() - 1 else "E  开始摆摊", 763, 472, 18)


func _charging() -> bool:
	return turn % 3 != 1

func _available(action: int) -> bool:
	return (action != 1 or snacks > 0) and (action != 2 or (talked_to_xiaohui and not song_used))

func _act(action: int) -> void:
	if phase != Phase.BATTLE:
		return
	if not _available(action):
		line_two = "洋芋粑吃完了。" if action == 1 else "这场擂台上，小惠只能接一次山歌。"
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
			line_one = "主角开口跑调。小惠隔着窄窄的水泥路接住了下句。"
			cue = "打断！" if heavy else "有人接歌！"
			cue_color = MINT
			if heavy:
				hit = 0
			_sound(392.0, 587.0, 0.38)
	impact = 0.5
	if boss_hp <= 0:
		boss_hp = 0
		phase = Phase.WIN
		line_two = "裁判：算你赢。你俩一个跑调，一个还敢接。"
		return
	hero_hp = maxi(0, hero_hp - hit)
	line_two = "裁判的招被化解了。" if hit == 0 else "裁判还手，你掉了 %d 点体力。" % hit
	if hero_hp == 0:
		phase = Phase.LOSE
		line_two = "裁判：去摊上吃饱了再来。我在超市门口等你。"
	turn += 1

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

func _meter(x: float, y: float, current: int, maximum: int, color: Color) -> void:
	_rect(x, y, 186, 7, Color("#47534f"))
	_rect(x, y, roundf(186.0 * current / maximum), 7, color)

func _draw_market_crowd() -> void:
	var coats := [Color("#80645d"), Color("#5b6e6c"), Color("#76556a"), Color("#7e7954")]
	for index in range(5):
		var direction := 1 if index % 2 == 0 else -1
		var offset := fposmod(elapsed * (27.0 + index * 4.0) + index * 203.0, 1030.0)
		var x := offset - 35.0 if direction == 1 else 995.0 - offset
		var baseline := 345.0 + float(index % 3) * 5.0
		var gait := int(elapsed * 8.0 + index) % 2
		_person(x, baseline, coats[index % coats.size()], Color("#4a3d3a"), direction, false, gait)


func _stall() -> void:
	_person(186, 347, Color("#665482"), Color("#5e3b39"), 1, false, 0)
	_rect(162, 332, 117, 40, Color("#653e31"))
	_rect(163, 328, 116, 7, Color("#ffc078"))
	for i in range(6):
		_rect(158 + i * 21, 291, 21, 15, Color("#c75a4c") if i % 2 == 0 else Color("#f8c783"))
	_rect(158, 306, 126, 4, INK)
	_rect(165, 310, 4, 19, Color("#7e4e38"))
	_rect(275, 310, 4, 19, Color("#7e4e38"))
	_rect(184, 267, 73, 25, INK)
	_type("洋芋粑", 198, 285, 15, GOLD)
	_rect(205, 321, 54, 7, INK)
	for i in range(3):
		_rect(209 + i * 16, 317, 12, 6, GOLD)
		var drift := fmod(elapsed * 20.0 + i * 11.0, 34.0)
		_rect(214 + i * 16 + roundf(sin(drift * 0.19) * 3.0), 318 - drift, 3, 3, Color(1.0, 0.95, 0.87, 1.0 - drift / 34.0))

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
	_draw_market_crowd()
	_stall()

	_person(hero_x, STREET, Color("#4d8e92"), Color("#34494e"), facing, false, step)
	if not won_match:
		_person(BOSS_X, STREET, Color("#be5951"), Color("#633957"), -1, true, 0)
		if phase == Phase.BATTLE and _charging():
			var glow := 0.5 + sin(elapsed * 6.0) * 0.24
			draw_circle(Vector2(BOSS_X - 16, STREET - 30), 5.0, Color(1.0, 0.69, 0.36, glow))
	if impact > 0.0:
		_type(cue, BOSS_X - 26, STREET - 65 - (0.5 - impact) * 32.0, 25, cue_color)

	_rect(26, 24, 270, 77, INK)
	_rect(26, 24, 5, 77, GOLD)
	_type("贵州 · 花江镇", 46, 52, 17, GOLD)
	_type("洋芋粑帝国", 46, 84, 29)

	if phase == Phase.BATTLE:
		_rect(340, 24, 594, 77, INK)
		_type("你  %d / %d" % [hero_hp, HERO_MAX], 364, 52, 17)
		_meter(364, 72, hero_hp, HERO_MAX, MINT)
		_type("裁判  %d / %d" % [boss_hp, BOSS_MAX], 714, 52, 17)
		_meter(714, 72, boss_hp, BOSS_MAX, RED)
		_rect(622, 112, 283, 36, INK)
		_type("裁判蓄力 · 重击" if _charging() else "裁判试探 · 轻击", 642, 136, 17, GOLD if _charging() else LIGHT)
	elif phase == Phase.WALK:
		var target_x := 211.0 if not talked_to_xiaohui else (870.0 if won_match else 653.0)
		var prompt := "找小惠" if not talked_to_xiaohui else ("去完成开张" if won_match else "去超市门口")
		var marker_y := 279.0 + sin(elapsed * 3.0) * 3.0
		_rect(target_x - 46, marker_y - 18, 132, 25, INK)
		_type("▼ " + prompt, target_x - 39.0, marker_y, 14, GOLD)

	_rect(26, 385, 908, 130, Color("#192b2bee"))
	_rect(26, 385, 908, 2, GOLD)
	_type(line_one, 46, 410, 18)
	if not line_two.is_empty():
		_type(line_two, 46, 431, 15, MINT)

	if phase == Phase.BATTLE:
		for index in range(ACTIONS.size()):
			var box := _action_rect(index)
			var enabled := _available(index)
			_button_frame(box, enabled)
			var detail: String = ACTIONS[index][1]
			if index == 1:
				detail = "%s · 剩 %d 个" % [detail, snacks]
			elif index == 2 and not enabled:
				detail = "已用过" if song_used else "先去找小惠"
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
