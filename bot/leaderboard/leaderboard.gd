extends Control

@onready var _1_st: RichTextLabel = %"1st"
@onready var _2_nd: RichTextLabel = %"2nd"
@onready var _3_rd: RichTextLabel = %"3rd"

func update_label(idx: int, username: String):
	var labels: Array[RichTextLabel] = [_1_st, _2_nd, _3_rd]
	var colors: Array[String] = ["gold", "silver", "peru"]
	labels[idx].parse_bbcode("[color=%s]%s[/color]\n%d" % [
		colors[idx], (await Twitch.bot.get_user(username)).display_name,
		Store.viewer(username).plushiedex.size()
	])

var timer: SceneTreeTimer

func _ready() -> void:
	timer = get_tree().create_timer(1)

func _process(delta: float) -> void:
	if timer.time_left > 0.0: return
	timer = get_tree().create_timer(1)
	
	var viewers = Store.viewers.keys().duplicate()
	viewers.sort_custom(func(a: String, b: String):
		return Store.viewer(a).plushiedex.size() > Store.viewer(b).plushiedex.size()
	)

	for i in range(min(viewers.size(), 3)):
		update_label(i, viewers[i])
