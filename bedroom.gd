extends "res://game_canvas.gd"

enum Phase { MONOLOGUE, DECISION, RESULT }

const BACKGROUND = preload("res://art/xiaohang-bedroom.png")
const RunProgress = preload("res://chapter_progress.gd")
const STUDY := 0
const BODY := 1
const CONTINUE_BUTTON := Rect2(746, 448, 168, 48)

var phase := Phase.MONOLOGUE

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E, KEY_ENTER:
				_advance()
			KEY_1:
				_choose(STUDY)
			KEY_2:
				_choose(BODY)
			KEY_R:
				get_tree().reload_current_scene()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cursor := get_global_mouse_position()
		if phase == Phase.DECISION:
			for choice in range(2):
				if _choice_rect(choice).has_point(cursor):
					_choose(choice)
					return
		elif CONTINUE_BUTTON.has_point(cursor):
			_advance()

func _advance() -> void:
	match phase:
		Phase.MONOLOGUE:
			phase = Phase.DECISION
		Phase.RESULT:
			get_tree().change_scene_to_file("res://school.tscn")
	queue_redraw()

func _choose(choice: int) -> void:
	if phase != Phase.DECISION:
		return
	RunProgress.upgrade = RunProgress.Upgrade.STUDY if choice == STUDY else RunProgress.Upgrade.BODY
	phase = Phase.RESULT
	_sound(360.0, 620.0, 0.27)
	queue_redraw()

func _choice_rect(index: int) -> Rect2:
	return Rect2(46 + index * 441, 443, 427, 57)

func _draw() -> void:
	_rect(0, 0, 960, 540, INK)
	var room_source := Rect2(0, 0, BACKGROUND.get_width(), BACKGROUND.get_height() * 0.79)
	draw_texture_rect_region(BACKGROUND, Rect2(0, 0, 960, 427), room_source)
	if phase == Phase.RESULT:
		_rect(0, 0, 960, 427, Color("#111824da"))
	_rect(26, 24, 235, 70, INK)
	_rect(26, 24, 4, 70, GOLD)
	_type("第一章 · 临近期末", 45, 51, 16, GOLD)
	_type("小航的房间", 45, 80, 26)
	_rect(26, 383, 908, 132, Color("#192b2bf7"))
	_rect(26, 383, 908, 2, GOLD)

	match phase:
		Phase.MONOLOGUE:
			_type("小航", 46, 408, 17, GOLD)
			_type("期末考试快到了。我今天就赚到这么一个洋芋粑。", 120, 408, 18)
			_type("洋芋粑系统说，这一个能提升智力，也能强化身体。我该怎么选？", 46, 432, 16, MINT)
			_draw_continue("E  想一想")
		Phase.DECISION:
			_type("洋芋粑系统", 46, 408, 17, GOLD)
			_type("只有一个洋芋粑，只能选一项。", 168, 408, 18)
			_draw_choice(STUDY, "1  提升学习能力", "现在吃。脑子更清楚，复习和解题更快。")
			_draw_choice(BODY, "2  提升身体机能", "留到明早吃。体力与力量会暂时增强。")
		Phase.RESULT:
			var line := "吃完后，再看同一道题，刚才卡住的地方一下就想通了。"
			var detail := "系统：学习能力已提升。洋芋粑剩余 0 个。"
			if RunProgress.upgrade == RunProgress.Upgrade.BODY:
				line = "小航把唯一一个洋芋粑包好，塞进书包。明早再用。"
				detail = "系统：已选择身体强化。随身洋芋粑 1 个。"
			_type("小航", 46, 408, 17, GOLD)
			_type(line, 120, 408, 18)
			_type(detail, 46, 432, 16, MINT)
			_draw_continue("E  第二天")

func _draw_continue(label: String) -> void:
	_button_frame(CONTINUE_BUTTON, true)
	_type(label, CONTINUE_BUTTON.position.x + 15, 480, 17)

func _draw_choice(index: int, label: String, detail: String) -> void:
	var box := _choice_rect(index)
	_button_frame(box, true)
	_type(label, box.position.x + 14, 466, 18)
	_type(detail, box.position.x + 14, 489, 14, GOLD)
