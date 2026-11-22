extends "res://game_canvas.gd"

enum Step { WASH, PEEL, STEAM, MIX, SHAPE, FRY, SAUCE, REVIEW, CLOSED, QUEUE }

const MARKET = preload("res://art/town-market.png")
const ORDERS := [
	["早班赶场的嬢嬢", true, true, 0],
	["买菜的大叔", true, false, 1],
	["来赶场的街坊", false, true, 2],
]
const SAUCES := ["番茄酱", "油泼辣子", "芥末酱"]
const SAUCE_COLORS := [Color("#e27358"), Color("#bd503b"), Color("#e3bd52")]
const STATIONS := ["洗土豆", "去皮", "蒸土豆", "拌料", "揉饼", "平底锅", "加酱", "交单"]
const WORK := Rect2(293, 105, 641, 290)
const SUBMIT := Rect2(711, 451, 207, 51)
const COOK_MIN := 2.7
const COOK_MAX := 4.5
const STEAM_LENGTH := 2.6
const HANDOFF_SECONDS := 1.1
const COUNTER_X := 391.0
const QUEUE_GAP := 157.0
const CUSTOMER_Y := 390
const CUSTOMER_COATS := [Color("#a96679"), Color("#526e68"), Color("#716382")]
const CUSTOMER_HATS := [Color("#733d46"), Color("#434d52"), Color("#57423b")]
const PAPER := Color("#f5dfb5")
const WOOD := Color("#986247")
const DARK_WOOD := Color("#56382c")
const PALE := Color("#d5bb91")
const CARROT := Color("#fc9a49")
const ONION := Color("#94b962")

var step := Step.QUEUE
var order_index := 0
var progress := 0
var carrots := false
var onions := false
var sauce := -1
var steam_started := false
var fry_side := -1
var stage_time := 0.0
var elapsed := 0.0
var sides: Array[float] = []
var scores: Array[int] = []
var review: Array[String] = []

func _ready() -> void:
	super._ready()
	Music.play("cooking")

func _process(delta: float) -> void:
	elapsed += delta
	if (step == Step.STEAM and steam_started) or (step == Step.FRY and fry_side >= 0) or step == Step.REVIEW:
		stage_time = minf(stage_time + delta, 30.0)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_E, KEY_ENTER, KEY_SPACE:
				_advance()
			KEY_1:
				_choose(0)
			KEY_2:
				_choose(1)
			KEY_3:
				_choose(2)
			KEY_R:
				get_tree().reload_current_scene()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pointer := get_global_mouse_position()
		if SUBMIT.has_point(pointer):
			_advance()
		elif step == Step.MIX or step == Step.SAUCE:
			var options := 2 if step == Step.MIX else 3
			for index in range(options):
				if _option_rect(index).has_point(pointer):
					_choose(index)
					break

func _choose(index: int) -> void:
	if step == Step.MIX:
		match index:
			0:
				carrots = not carrots
			1:
				onions = not onions
			_:
				return
	elif step == Step.SAUCE:
		sauce = index
	else:
		return
	_sound(372.0 + index * 78.0, 430.0 + index * 78.0, 0.08)

func _can_advance() -> bool:
	match step:
		Step.STEAM:
			return not steam_started or stage_time >= STEAM_LENGTH
		Step.SAUCE:
			return sauce >= 0
		Step.REVIEW:
			return stage_time >= HANDOFF_SECONDS
	return true

func _advance() -> void:
	if not _can_advance():
		return
	match step:
		Step.QUEUE:
			step = Step.WASH
			_sound(358.0, 550.0, 0.17)
		Step.WASH:
			_work_toward(3, Step.PEEL, 310.0)
		Step.PEEL:
			_work_toward(3, Step.STEAM, 220.0)
		Step.STEAM:
			if not steam_started:
				steam_started = true
				stage_time = 0.0
				_sound(188.0, 270.0, 0.14)
			else:
				step = Step.MIX
				_sound(480.0, 610.0, 0.16)
		Step.MIX:
			_work_toward(3, Step.SHAPE, 155.0)
		Step.SHAPE:
			_work_toward(2, Step.FRY, 193.0)
		Step.FRY:
			_fry()
		Step.SAUCE:
			_review_order()
		Step.REVIEW:
			if order_index + 1 == ORDERS.size():
				step = Step.CLOSED
			else:
				_next_order()
		Step.CLOSED:
			get_tree().change_scene_to_file("res://bedroom.tscn")

func _work_toward(count: int, following: Step, pitch: float) -> void:
	progress += 1
	_sound(pitch + progress * 24.0, pitch + progress * 60.0, 0.10)
	if progress == count:
		progress = 0
		step = following

func _fry() -> void:
	if fry_side == -1:
		fry_side = 0
	else:
		sides.append(stage_time)
		if fry_side == 1:
			step = Step.SAUCE
		else:
			fry_side = 1
	stage_time = 0.0
	_sound(230.0, 98.0, 0.24)

func _doneness(time: float) -> String:
	if time < COOK_MIN:
		return "偏生"
	if time > COOK_MAX:
		return "煎焦"
	return "金黄"

func _review_order() -> void:
	var order: Array = ORDERS[order_index]
	var grade := 100
	review.clear()
	if carrots != order[1] or onions != order[2]:
		var mistakes := int(carrots != order[1]) + int(onions != order[2])
		grade -= mistakes * 12
		review.append("配料和订单不符")
	if sauce != order[3]:
		grade -= 28
		review.append("酱放错了")
	var first := _doneness(sides[0])
	var second := _doneness(sides[1])
	grade -= 15 * (int(first != "金黄") + int(second != "金黄"))
	review.push_front("正面%s，反面%s" % [first, second])
	if review.size() == 1 and first == "金黄" and second == "金黄":
		review.append("配料和酱也都对上了")
	scores.append(grade)
	step = Step.REVIEW
	stage_time = 0.0
	_sound(440.0, 660.0, 0.28)

func _next_order() -> void:
	order_index += 1
	step = Step.WASH
	progress = 0
	carrots = false
	onions = false
	sauce = -1
	steam_started = false
	fry_side = -1
	stage_time = 0.0
	sides.clear()
	review.clear()

func _button_text() -> String:
	match step:
		Step.QUEUE:
			return "E  接单"
		Step.WASH:
			return "E  冲洗 (%d/3)" % progress
		Step.PEEL:
			return "E  削皮 (%d/3)" % progress
		Step.STEAM:
			if not steam_started:
				return "E  上蒸锅"
			return "E  取出" if _can_advance() else "蒸锅加热中"
		Step.MIX:
			return "E  捣碎拌匀 (%d/3)" % progress
		Step.SHAPE:
			return "E  揉成饼 (%d/2)" % progress
		Step.FRY:
			return ["E  下锅", "E  翻面", "E  起锅"][fry_side + 1]
		Step.SAUCE:
			return "E  上盘交单"
		Step.REVIEW:
			if not _can_advance():
				return "交餐中"
			return "E  收好摊位" if order_index + 1 == ORDERS.size() else "E  接下一单"
		Step.CLOSED:
			return "E  收摊回家"
	return ""

func _hint() -> String:
	match step:
		Step.WASH:
			return "把土豆上的泥冲干净。"
		Step.PEEL:
			return "转一转土豆，把剩下的皮削掉。"
		Step.STEAM:
			return "等进度条蒸满，再把熟土豆取出来。"
		Step.MIX:
			return "按订单选料。可以取消勾选，再把土豆捣碎拌匀。"
		Step.SHAPE:
			return "把土豆泥团紧、压成圆饼。"
		Step.FRY:
			if fry_side < 0:
				return "把生饼放到平底锅里。"
			return "计时到绿色区间时翻面或起锅。"
		Step.SAUCE:
			return "按订单选一种酱，确认后再上盘。"
		Step.CLOSED:
			return "小惠：最后一块给自己留着，回家啦。"
	return ""

func _option_rect(index: int) -> Rect2:
	return Rect2(308 + index * 130, 445, 122, 47)

func _draw() -> void:
	if step == Step.QUEUE or step == Step.REVIEW:
		_draw_queue()
		return
	draw_texture_rect(MARKET, Rect2(0, 0, 960, 540), false)
	_rect(0, 0, 960, 540, Color("#17292b8c"))
	_draw_header()
	_draw_order()
	_draw_work()
	_draw_controls()

func _draw_queue() -> void:
	draw_texture_rect(MARKET, Rect2(0, 0, 960, 540), false)
	_rect(26, 24, 258, 73, INK)
	_rect(26, 24, 5, 73, GOLD)
	_type("贵州 · 花江镇", 46, 51, 17, GOLD)
	_type("小航的洋芋粑摊", 46, 81, 24)

	var serving := step == Step.REVIEW
	var first_waiting := order_index + int(serving)
	var waiting := ORDERS.size() - first_waiting
	_rect(723, 24, 211, 60, INK)
	_type("已出餐  %d / %d" % [scores.size(), ORDERS.size()], 742, 48, 16, GOLD)
	_type("排队  %d 人" % waiting, 742, 70, 15, LIGHT)

	_draw_street_stall()
	var filing := 1.0 if not serving else _queue_progress()
	for index in range(first_waiting, ORDERS.size()):
		var slot := index - first_waiting
		var x := COUNTER_X + QUEUE_GAP * (slot + 1.0 - filing)
		var pace := 0 if filing >= 1.0 else int(stage_time * 11.0) % 2
		_person(x, CUSTOMER_Y, CUSTOMER_COATS[index], CUSTOMER_HATS[index], -1, true, pace)
		_customer_label(x, ORDERS[index][0], slot == 0)
	if serving and filing < 1.0:
		var exiting := lerpf(COUNTER_X, 1040.0, filing)
		_person(exiting, CUSTOMER_Y + 9, CUSTOMER_COATS[order_index], CUSTOMER_HATS[order_index], 1, true, int(stage_time * 11.0) % 2)
		_rect(exiting + 15, CUSTOMER_Y - 12, 15, 10, PAPER)
		_rect(exiting + 16, CUSTOMER_Y - 13, 12, 3, GOLD)

	_rect(26, 407, 908, 113, INK)
	_rect(26, 407, 908, 2, GOLD)
	if serving:
		_type("%s  ·  本单 %d 分" % [ORDERS[order_index][0], scores.back()], 46, 444, 21, GOLD)
		_type("。".join(review), 46, 472, 16, MINT)
		if waiting > 0:
			_type("%s走到摊前了。" % ORDERS[first_waiting][0] if filing >= 1.0 else "客人拿到洋芋粑，后面的人往前补位。", 46, 497, 14, PALE)
		else:
			_type("这轮排队的客人都拿到洋芋粑了。", 46, 497, 14, PALE)
	else:
		_type(ORDERS[order_index][0], 46, 444, 20, GOLD)
		_type(_customer_request(), 46, 475, 19, LIGHT)
	_button_frame(SUBMIT, _can_advance())
	_type(_button_text(), 728, 483, 17, LIGHT if _can_advance() else PALE)

func _queue_progress() -> float:
	return smoothstep(0.0, HANDOFF_SECONDS, stage_time)

func _customer_request() -> String:
	var order: Array = ORDERS[order_index]
	var filling := "胡萝卜碎和葱花都要" if order[1] and order[2] else ("只加胡萝卜碎" if order[1] else "只加葱花")
	return "来一个洋芋粑，%s，加%s。" % [filling, SAUCES[order[3]]]

func _customer_label(x: float, label: String, first: bool) -> void:
	var width := maxf(88.0, label.length() * 15.0 + 18.0)
	_rect(x - width * 0.5, CUSTOMER_Y - 93, width, 26, INK)
	_type(label, x - width * 0.5 + 9, CUSTOMER_Y - 75, 15, GOLD if first else PALE)

func _draw_street_stall() -> void:
	_person(220, CUSTOMER_Y - 6, Color("#498d96"), Color("#3a3635"), 1, true, 0)
	_rect(116, 266, 207, 23, DARK_WOOD)
	for panel in range(7):
		var color := Color("#b95848") if panel % 2 == 0 else PAPER
		_rect(115 + panel * 30, 260, 30, 20, color)
	_rect(124, 281, 7, 72, DARK_WOOD)
	_rect(310, 281, 7, 72, DARK_WOOD)
	_rect(164, 227, 110, 34, INK)
	_rect(164, 227, 110, 3, GOLD)
	_type("洋芋粑", 193, 251, 20, GOLD)
	_rect(123, 356, 200, 40, DARK_WOOD)
	_rect(125, 354, 194, 7, WOOD)
	_rect(125, 349, 200, 5, PAPER)
	_disk(Vector2(260, 346), 40, 11, INK)
	for cake in range(3):
		_disk(Vector2(240 + cake * 20, 344), 9, 4, Color("#edb15f"))


func _draw_header() -> void:
	_rect(26, 18, 908, 66, INK)
	_rect(26, 18, 5, 66, GOLD)
	_type("小航的洋芋粑摊", 45, 45, 25)
	for index in range(STATIONS.size()):
		var x := 48 + index * 110
		var current := index == int(step)
		var complete := index < int(step)
		if current:
			_rect(x - 3, 54, 102, 22, Color("#3d5c55"))
		var color := GOLD if current else (MINT if complete else PALE)
		_type(STATIONS[index], x + 6, 71, 14, color)

func _draw_order() -> void:
	var order: Array = ORDERS[order_index]
	_rect(26, 105, 247, 290, PAPER)
	_rect(26, 105, 247, 6, GOLD)
	_type("订单  %d / %d" % [order_index + 1, ORDERS.size()], 46, 143, 21, INK)
	_type(order[0], 46, 177, 17, DARK_WOOD)
	_rect(46, 192, 205, 2, WOOD)
	_type("配料", 46, 227, 15, DARK_WOOD)
	_type("胡萝卜碎  " + ("要" if order[1] else "不要"), 46, 254, 16, INK)
	_type("葱花         " + ("要" if order[2] else "不要"), 46, 280, 16, INK)
	_type("酱料", 46, 318, 15, DARK_WOOD)
	_rect(46, 332, 18, 15, SAUCE_COLORS[order[3]])
	_type(SAUCES[order[3]], 74, 346, 18, INK)
	_type("后面还有 %d 位客人" % (ORDERS.size() - order_index - 1), 46, 377, 13, DARK_WOOD)

func _draw_work() -> void:
	draw_rect(WORK, DARK_WOOD)
	for board in range(9):
		var y := 111 + board * 31
		_rect(299, y, 629, 28, WOOD if board % 2 == 0 else Color("#a66d4d"))
		_rect(299, y + 25, 629, 3, Color("#754a39"))
	var center := Vector2(610, 232)
	match step:
		Step.WASH, Step.PEEL:
			_disk(center + Vector2(0, 16), 144, 64, Color("#493c36"))
			_disk(center, 138, 62, Color("#b9d9d3") if step == Step.WASH else PAPER)
			_disk(center, 119, 48, Color("#81aeb4") if step == Step.WASH else PALE)
			_draw_raw(center)
		Step.STEAM:
			_draw_pot(center)
			if steam_started:
				_draw_gauge(stage_time / STEAM_LENGTH, false)
		Step.MIX, Step.SHAPE:
			_disk(center + Vector2(0, 14), 142, 62, DARK_WOOD)
			_disk(center, 140, 62, Color("#e4cba3"))
			_disk(center, 118, 48, Color("#b18f68"))
			var roundness := progress if step == Step.SHAPE else 0
			_disk(center, 72 - roundness * 7, 36 + roundness * 3, Color("#f2ce80"))
			_scatter(center)
		Step.FRY:
			_draw_pan(center)
			if fry_side >= 0:
				_draw_gauge(stage_time / 7.0, true)
		Step.SAUCE:
			_draw_plate(center)
		Step.CLOSED:
			_rect(393, 147, 438, 198, PAPER)
			_type("今天卖完了", 416, 185, 26, INK)
			var total := 0
			for index in range(scores.size()):
				total += scores[index]
				_type("第 %d 单  %d 分" % [index + 1, scores[index]], 417, 219 + index * 26, 17, DARK_WOOD)
			_type("平均评价  %d 分" % roundi(float(total) / scores.size()), 417, 319, 19, INK)

func _draw_raw(center: Vector2) -> void:
	var peels_left := 3 - progress if step == Step.PEEL else 3
	var potato := Color("#e5b967") if step == Step.PEEL else Color("#aa764d")
	_disk(center, 69, 31, potato)
	_disk(center - Vector2(10, 7), 54, 19, potato.lightened(0.13))
	for index in range(peels_left):
		var x := center.x - 32 + 28 * index
		_rect(x, center.y + 13, 12, 7, Color("#885639"))
	if step == Step.WASH:
		for index in range(3 - progress):
			_rect(center.x - 35 + 28 * index, center.y - 8 + (index % 2) * 13, 11, 8, Color("#634539"))
		for index in range(progress + 1):
			_rect(center.x - 88 + 48 * index, center.y + 28, 16, 4, Color("#d3eee1"))

func _draw_pot(center: Vector2) -> void:
	_rect(center.x - 132, center.y + 10, 264, 13, INK)
	_rect(center.x - 105, center.y - 1, 210, 59, Color("#688c8a"))
	_rect(center.x - 98, center.y + 41, 196, 13, Color("#49706d"))
	_disk(center - Vector2(0, 7), 113, 28, Color("#a3c5b9"))
	_disk(center - Vector2(0, 8), 101, 20, Color("#375554"))
	if steam_started:
		_disk(center - Vector2(0, 9), 110, 26, Color("#93af9e"))
		_rect(center.x - 20, center.y - 44, 40, 12, INK)
		for index in range(6):
			var rise := fposmod(elapsed * 25.0 + index * 13, 58.0)
			var vapor := Color(0.93, 0.97, 0.88, 0.75 * (1.0 - rise / 58.0))
			_rect(center.x - 56 + index * 22 + sin(rise * 0.2) * 8, center.y - 25 - rise, 7, 7, vapor)
	else:
		_disk(center - Vector2(0, 6), 60, 16, Color("#e0b56c"))

func _draw_pan(center: Vector2) -> void:
	_rect(center.x + 95, center.y + 7, 134, 19, Color("#2d3434"))
	_rect(center.x + 132, center.y + 7, 97, 7, Color("#444745"))
	_disk(center + Vector2(0, 13), 142, 68, Color("#392f2b"))
	_disk(center, 142, 68, Color("#687172"))
	_disk(center, 128, 58, Color("#292c2b"))
	_disk(center, 103, 43, Color("#4c4733"))
	if fry_side >= 0:
		var visible_time := stage_time if fry_side == 0 else sides[0]
		_draw_cake(center, _cake_color(visible_time))
		for index in range(10):
			var spark := fposmod(elapsed * 49.0 + index * 19.0, 34.0)
			var angle := TAU * index / 10.0
			_rect(center.x + cos(angle) * (76 + spark), center.y + sin(angle) * 42 - spark / 4, 4, 3, GOLD)

func _draw_gauge(fraction: float, timing: bool) -> void:
	const X := 410
	const WIDTH := 400
	const Y := 354
	_rect(X, Y, WIDTH, 16, INK)
	_rect(X + 2, Y + 2, (WIDTH - 4) * clampf(fraction, 0.0, 1.0), 12, GOLD if timing else MINT)
	if timing:
		var left := X + WIDTH * COOK_MIN / 7.0
		var span := WIDTH * (COOK_MAX - COOK_MIN) / 7.0
		_rect(left, Y + 2, span, 12, Color("#79ae83"))
		var needle := X + WIDTH * clampf(fraction, 0.0, 1.0)
		_rect(needle - 2, Y - 4, 4, 24, LIGHT)
		_type("偏生", X, Y - 8, 13, LIGHT)
		_type("金黄", left + 29, Y - 8, 13, LIGHT)
		_type("煎焦", X + WIDTH - 32, Y - 8, 13, LIGHT)

func _cake_color(time: float) -> Color:
	return Color("#efc068") if time < COOK_MIN else (Color("#cd8440") if time <= COOK_MAX else Color("#734637"))

func _draw_plate(center: Vector2) -> void:
	_disk(center + Vector2(0, 12), 144, 68, DARK_WOOD)
	_disk(center, 140, 67, Color("#e0e4c4"))
	_disk(center, 116, 52, Color("#738d81"))
	_disk(center, 103, 45, PAPER)
	_draw_cake(center, _cake_color(maxf(sides[0], sides[1])))
	if sauce >= 0:
		var glaze: Color = SAUCE_COLORS[sauce]
		for index in range(9):
			var wave := sin(index * 1.5) * 14.0
			_rect(center.x - 48 + index * 11, center.y - 6 + wave, 13, 8, glaze)

func _draw_cake(center: Vector2, color: Color) -> void:
	_disk(center + Vector2(0, 8), 69, 34, color.darkened(0.30))
	_disk(center, 69, 34, color)
	_disk(center - Vector2(3, 5), 54, 25, color.lightened(0.12))
	_scatter(center)

func _scatter(center: Vector2) -> void:
	for index in range(13):
		var x := (index * 47 % 100) - 50
		var y := (index * 23 % 38) - 19
		var color := Color("#c39559")
		if index % 3 == 0 and carrots:
			color = CARROT
		elif index % 3 == 1 and onions:
			color = ONION
		_rect(center.x + x, center.y + y, 6, 4, color)

func _disk(center: Vector2, radius_x: float, radius_y: float, color: Color) -> void:
	for line in range(-int(radius_y), int(radius_y), 4):
		var width := roundf(radius_x * sqrt(1.0 - pow(float(line) / radius_y, 2.0)))
		_rect(center.x - width, center.y + line, width * 2.0, 4, color)

func _draw_controls() -> void:
	_rect(26, 407, 908, 113, INK)
	_type(_hint(), 45, 431, 17, MINT)
	if step == Step.MIX:
		_draw_option(0, "胡萝卜碎", CARROT, carrots)
		_draw_option(1, "葱花", ONION, onions)
	elif step == Step.SAUCE:
		for index in range(SAUCES.size()):
			_draw_option(index, SAUCES[index], SAUCE_COLORS[index], sauce == index)
	else:
		_type("E / 空格操作  ·  R 重新开摊", 46, 480, 15, PALE)
	_button_frame(SUBMIT, _can_advance())
	if not _can_advance():
		draw_rect(SUBMIT, Color("#192b2b77"))
	_type(_button_text(), 728, 483, 17, LIGHT if _can_advance() else PALE)

func _draw_option(index: int, label: String, swatch: Color, selected: bool) -> void:
	var box := _option_rect(index)
	_button_frame(box, true)
	if selected:
		draw_rect(box, GOLD, false, 2)
	_rect(box.position.x + 11, box.position.y + 17, 12, 12, swatch)
	_type("%d  %s" % [index + 1, label], box.position.x + 30, box.position.y + 30, 15, GOLD if selected else LIGHT)
