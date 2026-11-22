extends "res://game_canvas.gd"

enum Phase { ARRIVAL, MEMORY, CONFRONTATION, BATTLE, VICTORY, DEFEAT, AFTERMATH }

const RunProgress = preload("res://chapter_progress.gd")

const BACKGROUND = preload("res://art/school-gate.png")
const FLOOR_Y := 369
const HERO_MAX := 24
const ENEMY_X := [598.0, 722.0, 844.0]
const ENEMY_NAMES := ["跟班", "混混头子", "跟班"]
const ENEMY_MAX := [8, 16, 8]
const ENEMY_COLORS := [Color("#745f51"), Color("#ac5254"), Color("#737957")]
const ACTION_KEYS := [KEY_1, KEY_2, KEY_3]
const ACTION_LABELS := ["1  出招", "2  吃洋芋粑", "3  反击"]

var elapsed := 0.0
var phase := Phase.ARRIVAL
var hero_x := 128.0
var hero_hp := HERO_MAX
var xiaohui_x := 181.0
var step := 0
var facing := 1
var turn := 0
var enemy_hp := ENEMY_MAX.duplicate()
var power := 0
var snacks := 1
var impact := 0.0
var hit_mask := 0
var effect_x := 0.0
var effect_color := GOLD
var effect_text := ""
var speaker := "小惠"
var line := "你每天都留一个给我，今天记得也给自己留一个。"
var detail := "初三上学期快结束了。小航递过热乎的洋芋粑，和小惠并肩去上学。"

func _ready() -> void:
	super._ready()
	Music.play("school")
	if _study_training():
		snacks = 0

func _study_training() -> bool:
	return RunProgress.upgrade == RunProgress.Upgrade.STUDY

func _process(delta: float) -> void:
	elapsed += delta
	impact = maxf(0.0, impact - delta)
	if phase == Phase.ARRIVAL:
		_walk(delta)
	queue_redraw()

func _walk(delta: float) -> void:
	var direction := int(Input.is_physical_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT))
	direction -= int(Input.is_physical_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	if direction != 0:
		facing = direction
		step = int(elapsed * 12.0) % 2
		hero_x = clampf(hero_x + direction * delta * 175.0, 55.0, 370.0)
		xiaohui_x = move_toward(xiaohui_x, hero_x + 58.0, delta * 190.0)
		if hero_x >= 367.0:
			_advance()
	else:
		step = 0

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				get_tree().reload_current_scene()
			KEY_E, KEY_ENTER:
				_advance()
			KEY_1, KEY_2, KEY_3:
				_act(ACTION_KEYS.find(event.physical_keycode))
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var cursor := get_global_mouse_position()
		if phase == Phase.BATTLE:
			for action in range(ACTION_KEYS.size()):
				if _action_rect(action).has_point(cursor):
					_act(action)
					return
		elif Rect2(744, 452, 168, 44).has_point(cursor):
			_advance()

func _advance() -> void:
	match phase:
		Phase.ARRIVAL:
			phase = Phase.MEMORY
			hero_x = 381.0
			xiaohui_x = 448.0
			step = 0
			facing = 1
			speaker = "上一世"
			line = "也是这几个混混，在校门口堵住了小惠。"
			detail = "我挡在她面前。结果，他们的头儿把我打进了医院。"
			_sound(180.0, 85.0, 0.33)
		Phase.MEMORY:
			phase = Phase.CONFRONTATION
			speaker = "小惠"
			line = "别挡路。我说过了，别再来找我。"
			detail = "小航认出那几个混混。值班老师就在校门边。" if _study_training() else "混混头子和两个跟班仍堵在前面。小航认出了那张脸。"
		Phase.CONFRONTATION:
			if _study_training():
				phase = Phase.AFTERMATH
				xiaohui_x = 354.0
				speaker = "小惠"
				line = "老师过来了。他们刚才一看见老师，话都说不出来。"
				detail = "小航叫住了值班老师。老师把人带走，小航和小惠一起进了校门。"
				return
			phase = Phase.BATTLE
			xiaohui_x = 315.0
			speaker = "小航"
			line = "小惠，往后站一点。这回我知道怎么应付了。"
			detail = "系统提示：吃下洋芋粑，强化接下来三次出招。"
			_sound(230.0, 130.0, 0.24)
			Music.play("battle")
		Phase.VICTORY:
			phase = Phase.AFTERMATH
			speaker = "小航"
			line = "上一世，到这儿我就进医院了。这一世，真的不一样了。"
			detail = "小惠把掉在地上的书包捡起来。上课铃响了，两个人一起进了校门。"
			_sound(392.0, 523.0, 0.35)
			Music.play("school")
		Phase.AFTERMATH:
			get_tree().change_scene_to_file("res://classroom.tscn")
		Phase.DEFEAT:
			get_tree().reload_current_scene()

func _first_enemy() -> int:
	for index in range(enemy_hp.size()):
		if enemy_hp[index] > 0:
			return index
	return -1

func _incoming() -> int:
	var hit := 0
	for index in range(enemy_hp.size()):
		if enemy_hp[index] > 0:
			hit += (5 if turn % 2 == 0 else 3) if index == 1 else 2
	return hit

func _available(action: int) -> bool:
	return (action != 1 or snacks > 0) and (action != 2 or power > 0)

func _act(action: int) -> void:
	if phase != Phase.BATTLE:
		return
	if not _available(action):
		detail = "洋芋粑已经吃完了。" if action == 1 else "先吃洋芋粑，强化后才能用这招。"
		return

	var fortified := power > 0
	var target := _first_enemy()
	hit_mask = 0
	impact = 0.54
	effect_color = GOLD if fortified or action == 1 else RED
	effect_x = ENEMY_X[target]
	speaker = "小航"

	match action:
		0:
			var damage := 12 if fortified else 4
			enemy_hp[target] = maxi(0, enemy_hp[target] - damage)
			hit_mask = 1 << target
			effect_text = "−%d" % damage
			line = "强化后出招，最前面的对手站不稳了。" if fortified else "小航挡了回去，力气跟上一世差不多。"
			_sound(325.0, 106.0, 0.17)
		1:
			snacks -= 1
			power = 3
			effect_x = hero_x
			effect_text = "强化！"
			speaker = "洋芋粑系统"
			line = "力量提升。洋芋粑还烫嘴，手脚已经比刚才轻快了。"
			_sound(310.0, 780.0, 0.36)
		2:
			for index in range(enemy_hp.size()):
				if enemy_hp[index] > 0:
					enemy_hp[index] = maxi(0, enemy_hp[index] - 8)
					hit_mask |= 1 << index
			effect_x = ENEMY_X[1]
			effect_text = "全体 −8"
			line = "小航借着强化反击，围上来的三个人全被打退。"
			_sound(275.0, 78.0, 0.24)

	if fortified and action != 1:
		power -= 1
	if _first_enemy() == -1:
		phase = Phase.VICTORY
		speaker = "小惠"
		line = "小航，你没受伤吧？刚刚……你先吃的是洋芋粑？"
		detail = "混混头子和两个跟班全倒在地上。校门口一下安静下来。"
		return

	var hit := _incoming()
	if action == 1:
		hit = maxi(0, hit - 8)
	elif fortified:
		hit = maxi(0, hit - 3)
	hero_hp = maxi(0, hero_hp - hit)
	detail = "小航扛住了围攻，没掉体力。" if hit == 0 else "剩下的混混扑上来，小航失去 %d 点体力。" % hit
	turn += 1
	if hero_hp == 0:
		phase = Phase.DEFEAT
		speaker = "小航"
		line = "还是跟上一世一样，硬扛根本来不及。"
		detail = "再试一次。先吃洋芋粑，等强化生效。"

func _action_rect(index: int) -> Rect2:
	return Rect2(46 + index * 293, 446, 280, 55)

func _draw() -> void:
	draw_texture_rect(BACKGROUND, Rect2(0, 0, 960, 540), false)
	_draw_students()
	if phase == Phase.MEMORY:
		_rect(0, 0, 960, 383, Color("#32252da6"))
	_rect(26, 24, 246, 75, INK)
	_rect(26, 24, 5, 75, GOLD)
	_type("贵州 · 花江镇", 46, 51, 16, GOLD)
	_type("校门口", 46, 83, 29)
	if phase == Phase.BATTLE:
		_draw_battle_hud()
	_draw_dialogue()

func _draw_students() -> void:
	if power > 0 and phase == Phase.BATTLE:
		var shimmer := 0.18 + sin(elapsed * 8.0) * 0.07
		draw_circle(Vector2(hero_x, FLOOR_Y - 30), 44, Color(1.0, 0.75, 0.27, shimmer))
		for spark in range(8):
			var theta := TAU * spark / 8.0 + elapsed * 1.8
			var point := Vector2(hero_x, FLOOR_Y - 28) + Vector2(cos(theta) * 39, sin(theta) * 36)
			draw_rect(Rect2(point.round(), Vector2(4, 4)), GOLD)
	var xiaohui_step := step if phase == Phase.ARRIVAL else 0
	_person(xiaohui_x, FLOOR_Y - 4, Color("#76649e"), Color("#453038"), 1, false, xiaohui_step)
	_rect(xiaohui_x + 5, FLOOR_Y - 33 - xiaohui_step * 2, 4, 3, GOLD)
	_person(hero_x, FLOOR_Y, Color("#498d96"), Color("#3a3635"), facing, true, step)
	if _study_training() and phase == Phase.AFTERMATH:
		return
	for index in range(enemy_hp.size()):
		var x: float = ENEMY_X[index]
		var knocked: bool = enemy_hp[index] == 0
		var shirt: Color = ENEMY_COLORS[index]
		if knocked:
			_rect(x - 20, FLOOR_Y - 8, 37, 9, INK)
			_rect(x - 17, FLOOR_Y - 12, 27, 9, shirt)
			_rect(x + 9, FLOOR_Y - 11, 8, 8, Color("#efb786"))
		else:
			var recoil := impact * 18.0 if hit_mask & (1 << index) else 0.0
			_person(x + recoil, FLOOR_Y, shirt, Color("#453737"), -1, index == 1, 0)
		if phase == Phase.BATTLE and not knocked:
			_rect(x - 35, FLOOR_Y - 81, 70, 23, INK)
			_type(ENEMY_NAMES[index], x - 28 if index == 1 else x - 13, FLOOR_Y - 65, 14)
			_meter(x - 28, FLOOR_Y - 54, enemy_hp[index], ENEMY_MAX[index], RED, 56.0)
	if impact > 0.0 and not effect_text.is_empty():
		var rise := (0.54 - impact) * 42.0
		_rect(effect_x - 43, FLOOR_Y - 112 - rise, 100, 27, INK)
		_type(effect_text, effect_x - 34, FLOOR_Y - 92 - rise, 19, effect_color)

func _draw_battle_hud() -> void:
	_rect(317, 24, 617, 75, INK)
	_type("小航  %d / %d" % [hero_hp, HERO_MAX], 338, 51, 18)
	_meter(338, 72, hero_hp, HERO_MAX, MINT)
	var strength := "身体强化 · 剩 %d 次" % power if power > 0 else "身体强化未生效"
	_type(strength, 593, 51, 19, GOLD if power else LIGHT)
	_type("对方下一轮伤害  %d" % maxi(0, _incoming() - (3 if power > 0 else 0)), 594, 80, 14, RED)

func _draw_dialogue() -> void:
	_rect(26, 385, 908, 130, Color("#192b2bf3"))
	_rect(26, 385, 908, 2, GOLD)
	_type(speaker, 46, 409, 17, GOLD)
	_type(line, 151, 409, 18)
	_type(detail, 46, 431, 15, MINT)

	if phase == Phase.BATTLE:
		var summaries := [
			"最前面的敌人 · %d 点伤害" % (12 if power > 0 else 4),
			"强化三次出招 · 剩 %d 个" % snacks,
			"让所有对手各掉 8 点体力" if power > 0 else "吃下洋芋粑后解锁",
		]
		for action in range(ACTION_LABELS.size()):
			var bounds := _action_rect(action)
			var enabled := _available(action)
			_button_frame(bounds, enabled)
			var text_color := LIGHT if enabled else Color("#a1aca3")
			_type(ACTION_LABELS[action], bounds.position.x + 14, 468, 18, text_color)
			_type(summaries[action], bounds.position.x + 14, 491, 14, GOLD if enabled else text_color)

	else:
		var button := Rect2(744, 452, 168, 44)
		_button_frame(button, true)
		var label := "E  继续"
		if phase == Phase.ARRIVAL:
			label = "E  到校门口"
			_type("A / D 或 ← / → 往前走", 46, 477, 15, GOLD)
		elif phase == Phase.CONFRONTATION and _study_training():
			label = "E  找值班老师"
		elif phase == Phase.DEFEAT:
			label = "E  再试一次"
		elif phase == Phase.AFTERMATH:
			label = "E  去教室"
		_type(label, 762, 480, 17)
