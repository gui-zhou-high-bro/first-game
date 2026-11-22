extends "res://game_canvas.gd"

enum Phase { STORY, APPROACH, ENDING }

const BACKGROUND = preload("res://art/school-corridor.png")
const CONTINUE_BUTTON := Rect2(744, 452, 168, 44)
const HUI_X := 646.0
const MEET_X := 555.0
const FLOOR_Y := 371
const STORY = [
	["小惠", "隔壁班那个人又来问我，要不要跟他在一起。这一次，我答应了。", "我其实不喜欢他。可我想知道，小航听见这件事，到底会不会在意。"],
	["同学", "小航，你听说没？小惠跟隔壁班那个在一起了。", "放学铃刚响，小航收书包的手停了一下。"],
	["小航", "上一世也是这时候。我听了就装作不在意，从没问过她。", "后来她不再等我一起放学，我也没去叫她。话越来越少，连见面都变得客气。"],
	["小航", "刚听到的时候，我第一反应居然是想追上去。", "上一世没说清楚的话，这一世我得当面跟她说。"],
]
const FINAL_LINE := "小惠，等等。能跟你聊两句吗？"

var phase := Phase.STORY
var card_index := 0
var hero_x := 260.0
var facing := 1
var step := 0
var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	if phase == Phase.APPROACH:
		var direction := int(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
		direction -= int(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
		if direction != 0:
			facing = direction
			hero_x = clampf(hero_x + direction * delta * 185.0, 238.0, MEET_X)
			step = int(elapsed * 12.0) % 2
			if hero_x >= MEET_X:
				_meet()
		else:
			step = 0
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				get_tree().reload_current_scene()
			KEY_E, KEY_ENTER:
				_advance()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if CONTINUE_BUTTON.has_point(get_global_mouse_position()):
			_advance()

func _advance() -> void:
	match phase:
		Phase.STORY:
			if card_index + 1 < STORY.size():
				card_index += 1
			else:
				phase = Phase.APPROACH
		Phase.APPROACH:
			_meet()

func _meet() -> void:
	hero_x = MEET_X
	facing = 1
	step = 0
	phase = Phase.ENDING
	_sound(392.0, 523.0, 0.24)

func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(0, 0, 960, 540), false)
	_draw_people()
	if phase == Phase.STORY and card_index == 2:
		_rect(0, 0, 960, 383, Color("#27283794"))
	_rect(26, 24, 246, 75, INK)
	_rect(26, 24, 5, 75, GOLD)
	_type("初三 · 放学后", 46, 51, 16, GOLD)
	_type("走廊", 46, 83, 29)
	_draw_dialogue()

func _draw_people() -> void:
	if phase == Phase.STORY and card_index == 0:
		_draw_xiaohui(HUI_X, -1)
		_person(545.0, FLOOR_Y, Color("#69756a"), Color("#493d3d"), 1, true, 0)
		return
	_person(hero_x, FLOOR_Y, Color("#498d96"), Color("#3a3635"), facing, true, step)
	if phase == Phase.STORY and card_index == 1:
		_person(352.0, FLOOR_Y, Color("#6b7588"), Color("#453937"), -1, true, 0)
	else:
		_draw_xiaohui(HUI_X, -1 if phase == Phase.ENDING else 1)

func _draw_xiaohui(x: float, direction: int) -> void:
	_person(x, FLOOR_Y + 1, Color("#76649e"), Color("#453038"), direction, true, 0)
	_rect(x + 4, 325, 4, 3, GOLD)

func _draw_dialogue() -> void:
	_rect(26, 385, 908, 130, Color("#192b2bf3"))
	_rect(26, 385, 908, 2, GOLD)
	var card: Array = STORY[card_index]
	var speaker: String = card[0]
	var line: String = card[1]
	var detail: String = card[2]
	if phase == Phase.APPROACH:
		speaker = "小航"
		line = "小惠就在走廊尽头。现在过去，还来得及。"
		detail = "按 D 或 → 走过去，也可以按 E 叫住她。"
	elif phase == Phase.ENDING:
		speaker = "小航"
		line = FINAL_LINE
		detail = "小惠停下脚步，转过身。"
	_type(speaker, 46, 411, 17, GOLD)
	_type(line, 121, 411, 18)
	_type(detail, 46, 438, 15, MINT)
	if phase == Phase.ENDING:
		_type("R  重看本场对话", 46, 480, 14, GOLD)
	else:
		_button_frame(CONTINUE_BUTTON, true)
		_type("E  去找小惠" if phase == Phase.APPROACH else "E  继续", 761, 480, 17)
