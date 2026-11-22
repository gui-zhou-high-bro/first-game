extends "res://game_canvas.gd"

enum Phase { INTRO, WALK }

const BACKGROUND = preload("res://art/town-market.png")
const FIRST_PERSON = preload("res://art/xiaohui-pov.png")
const MARKET_CROWD = preload("res://art/market-crowd.ogg")
const STREET = 374
const INTRO = [
	["小惠", "醒啦？你守着锅都能睡着。再不翻面，洋芋粑要煎成锅巴咯。", "我一睁眼，青梅竹马小惠正俯身看着我。隔着水泥路，对面摊贩正吆喝。"],
	["小航", "小惠？我不是在集团五十周年庆上，吃了发芽洋芋做的粑粑就……", "上一世，我垄断了全世界的洋芋粑。这一世，我还在镇上守着自己的小摊。"],
	["洋芋粑系统", "叮！洋芋粑系统已激活。", "小惠：小航，你还要在这儿发多久的呆？收摊啦。明早我来叫你，一起上学。"],
]

var crowd := AudioStreamPlayer.new()
var phase := Phase.INTRO
var intro_page := 0
var hero_x := 130.0
var facing := 1
var talked_to_xiaohui := false
var line_one := ""
var line_two := ""
var elapsed := 0.0
var step := 0

func _ready() -> void:
	super._ready()
	var ambiance := MARKET_CROWD.duplicate() as AudioStreamOggVorbis
	ambiance.loop = true
	crowd.stream = ambiance
	crowd.volume_db = -11.0
	add_child(crowd)
	if DisplayServer.get_name() != "headless":
		crowd.play()

func _process(delta: float) -> void:
	elapsed += delta
	if phase == Phase.WALK:
		var direction := int(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
		direction -= int(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		if direction != 0:
			facing = direction
			step = int(elapsed * 12.0) % 2
			hero_x = clampf(hero_x + direction * delta * 184.0, 42.0, 911.0)
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
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Rect2(746, 441, 168, 47).has_point(get_global_mouse_position()):
			_interact()

func _interact() -> void:
	if phase == Phase.INTRO:
		_advance_intro()
	elif talked_to_xiaohui:
		get_tree().change_scene_to_file("res://bedroom.tscn")
	elif hero_x >= 116.0 and hero_x <= 310.0:
		talked_to_xiaohui = true
		line_one = "小航：给，你的洋芋粑。跟每天一样，趁热吃。"
		line_two = "小惠接过纸包，笑着等他收摊。"
		_sound(440.0, 660.0, 0.18)
	else:
		line_one = "小惠还在洋芋粑摊前等你。"
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
	line_two = "和小惠说话，收摊后回家。"

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

func _draw() -> void:
	if phase == Phase.INTRO:
		_draw_intro()
		return
	draw_texture_rect(BACKGROUND, Rect2(0, 0, 960, 540), false)
	_draw_market_crowd()
	_stall()
	_person(hero_x, STREET, Color("#4d8e92"), Color("#34494e"), facing, true, step)

	_rect(26, 24, 270, 77, INK)
	_rect(26, 24, 5, 77, GOLD)
	_type("贵州 · 花江镇", 46, 52, 17, GOLD)
	_type("洋芋粑帝国", 46, 84, 29)
	if not talked_to_xiaohui:
		var marker_y := 279.0 + sin(elapsed * 3.0) * 3.0
		_rect(165, marker_y - 18, 132, 25, INK)
		_type("▼ 找小惠", 172, marker_y, 14, GOLD)

	_rect(26, 385, 908, 130, Color("#192b2bee"))
	_rect(26, 385, 908, 2, GOLD)
	_type(line_one, 46, 410, 18)
	_type(line_two, 46, 431, 15, MINT)
	_type("A / D 或 ← / → 移动     ·     R 重开", 46, 475, 15, GOLD)
	_button_frame(Rect2(746, 441, 168, 47), true)
	_type("E  回家" if talked_to_xiaohui else "E  互动", 763, 472, 18)
