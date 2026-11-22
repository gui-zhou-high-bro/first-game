extends "res://game_canvas.gd"

enum Phase { TALK, DECISION, DONE }

const BACKGROUND = preload("res://art/classroom.png")
const RunProgress = preload("res://chapter_progress.gd")
const KEYS := [KEY_1, KEY_2, KEY_3]
const CONTINUE_BUTTON := Rect2(744, 452, 168, 44)

const CLASSROOM_ENTRY = [
	["小航", "教室里有同学在翻书，也有人趁着老师没来，凑在一起聊天。", "我和小惠不是同桌。她放下书包，从靠窗那排走到我跟前。"],
	["小航", "小惠比我大三岁。她小时候走丢，后来被镇上一户人家收养。", "她养家那几年条件不好，她入学晚，后来才和我成了同班同学。"],
]
const AFTER_FIGHT = [
	["小惠", "刚才他们那么多人。你伤着没有？让我看看。", ""],
	["小航", "没什么大事。你没事就好。", ""],
	["小惠", "我感觉你好像变了个人似的。没想到你这么厉害，能把那些混混都打跑。", ""],
	["小惠", "你以后都能像今天这样保护我吗，小航哥哥？", ""],
	["小航", "她明明比我大三岁，这时候偏偏叫我小航哥哥。", "我看着她，想起上一世那封没能早点读到的情书。"],
]
const AFTER_TEACHER = [
	["小惠", "刚才吓了我一跳。你没事吧？", ""],
	["小航", "没什么大事。老师来了，他们就散了。你没事就好。", ""],
	["小惠", "我感觉你好像变了个人似的。刚才你叫老师来，我一下就没那么怕了。", ""],
	["小惠", "要是以后再遇到这种事，我还能找你吗，小航哥哥？", ""],
	["小航", "她明明比我大三岁，这时候偏偏叫我小航哥哥。", "我看着她，想起上一世那封没能早点读到的情书。"],
]
const EXAM_PROMPT := [
	"初三上学期快结束了。下学期就要准备中考。",
	"上一世，我超常发挥进了省重点高中；小惠没考好，去了普通高中。",
]
const OPTION_LABELS := ["1  故意考差", "2  正常发挥", "3  帮助小惠"]
const OPTION_DETAILS := ["和小惠去同一所高中", "走上一世的路，争取省重点", "帮她一起备考，争取省重点"]
const OUTCOMES := [
	["这一次，我打算故意考差一点，跟小惠上同一所高中。", "小航决定改变自己的中考结果。这次，他想离她近一点。"],
	["中考我会照常考，像上一世一样争取进省重点。", "小航决定沿着上一世的升学路线走。至于小惠，这回他想主动一点。"],
	["我已经能把难题想明白了。我去问小惠，愿不愿意一起备考。", "小航决定帮小惠梳理错题。两个人都正常考，一起争取省重点。"],
]

var phase := Phase.TALK
var card_index := 0
var choice_index := -1
var classroom_lines: Array = []

func _ready() -> void:
	super._ready()
	RunProgress.exam_plan = RunProgress.ExamPlan.UNDECIDED
	classroom_lines = CLASSROOM_ENTRY + (AFTER_TEACHER if _study_training() else AFTER_FIGHT)
	Music.play("classroom")

func _study_training() -> bool:
	return RunProgress.upgrade == RunProgress.Upgrade.STUDY

func _choice_count() -> int:
	return 3 if _study_training() else 2

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				get_tree().reload_current_scene()
			KEY_E, KEY_ENTER:
				_advance()
			KEY_1, KEY_2, KEY_3:
				_choose(KEYS.find(event.physical_keycode))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cursor := get_global_mouse_position()
		if phase == Phase.DECISION:
			for choice in range(_choice_count()):
				if _choice_rect(choice).has_point(cursor):
					_choose(choice)
					return
		elif CONTINUE_BUTTON.has_point(cursor):
			_advance()

func _process(_delta: float) -> void:
	queue_redraw()

func _advance() -> void:
	if phase == Phase.DONE:
		get_tree().change_scene_to_file("res://hallway.tscn")
		return
	if phase != Phase.TALK:
		return
	if card_index + 1 == classroom_lines.size():
		phase = Phase.DECISION
	else:
		card_index += 1

func _choose(choice: int) -> void:
	if phase != Phase.DECISION or choice < 0 or choice >= _choice_count():
		return
	choice_index = choice
	RunProgress.exam_plan = [
		RunProgress.ExamPlan.SAME_SCHOOL,
		RunProgress.ExamPlan.ORIGINAL_PATH,
		RunProgress.ExamPlan.HELP_XIAOHUI,
	][choice]
	phase = Phase.DONE
	_sound(440.0, 620.0, 0.25)

func _choice_rect(index: int) -> Rect2:
	if _study_training():
		return Rect2(46 + index * 293, 446, 280, 55)
	return Rect2(46 + index * 441, 446, 427, 55)

func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(0, 0, 960, 540), false)
	var xiaohui_x := 548.0 if card_index > 0 else 571.0
	_person(410, 372, Color("#498d96"), Color("#3a3635"), 1, true, 0)
	_person(xiaohui_x, 373, Color("#76649e"), Color("#453038"), -1, true, 0)
	_rect(xiaohui_x + 4, 327, 4, 3, GOLD)
	_rect(26, 24, 246, 75, INK)
	_rect(26, 24, 5, 75, GOLD)
	_type("初三 · 上课前", 46, 51, 16, GOLD)
	_type("教室", 46, 83, 29)
	_draw_dialogue()

func _draw_dialogue() -> void:
	_rect(26, 385, 908, 130, Color("#192b2bf3"))
	_rect(26, 385, 908, 2, GOLD)
	var card: Array = classroom_lines[card_index]
	var speaker: String = card[0]
	var line: String = card[1]
	var detail: String = card[2]
	if phase == Phase.DECISION:
		speaker = "小航"
		line = EXAM_PROMPT[0]
		detail = EXAM_PROMPT[1]
	elif phase == Phase.DONE:
		speaker = "小航"
		line = OUTCOMES[choice_index][0]
		detail = OUTCOMES[choice_index][1]
	_type(speaker, 46, 411, 17, GOLD)
	_type(line, 121, 411, 18)
	if not detail.is_empty():
		_type(detail, 46, 438, 15, MINT)
	if phase == Phase.TALK:
		_button_frame(CONTINUE_BUTTON, true)
		_type("E  继续", 762, 480, 17)
	elif phase == Phase.DECISION:
		for choice in range(_choice_count()):
			var bounds := _choice_rect(choice)
			_button_frame(bounds, true)
			_type(OPTION_LABELS[choice], bounds.position.x + 14, 468, 18)
			_type(OPTION_DETAILS[choice], bounds.position.x + 14, 491, 14, GOLD)
	else:
		_type("已决定中考路线     ·     R 重看本场对话", 46, 477, 15, GOLD)
		_button_frame(CONTINUE_BUTTON, true)
		_type("E  放学后", 762, 480, 17)
