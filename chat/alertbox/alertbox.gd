class_name AlertBox
extends Control

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var label: RichTextLabel = $RichTextLabel
@onready var audio: AudioStreamPlayer = $AudioStreamPlayer

var alerts := {}

func _ready() -> void:
	var alerts_dir := DirAccess.open("res://assets/alerts")
	if alerts_dir:
		alerts_dir.list_dir_begin()
		var alert := alerts_dir.get_next()
		while alert != "":
			if alerts_dir.current_is_dir():
				alerts[alert] = {
					animation = load("res://assets/alerts/%s/%s.gif" % [alert, alert]),
					sound = load("res://assets/alerts/%s/%s.wav" % [alert, alert])
				}
			alert = alerts_dir.get_next()
	else:
		print("Alerts directory not found!")

	Twitch.broadcaster_eventsub.event.connect(_on_twitch_eventsub_event)

func play(alert: String, message: String) -> void:
	play_raw(alerts[alert].animation, alerts[alert].sound, message, 10.0)

func play_raw(sprite_frames: SpriteFrames, sound: AudioStream, message: String, sprite_scale: float = 1.0) -> void:
	sprite.scale = Vector2(sprite_scale, sprite_scale)

	sprite_frames.set_animation_loop("default", false)
	sprite.sprite_frames = sprite_frames
	sprite.frame = 0
	
	audio.stream = sound

	var alert_size := sprite_frames.get_frame_texture("default", sprite.frame).get_size() * sprite.scale
	label.position.y = alert_size.y
	label.size.x = alert_size.x
	label.text = "[center]%s[/center]" % message

	sprite.play()
	audio.play()

	await audio.finished
	await sprite.animation_finished
	sprite.sprite_frames = null
	label.text = ""

func _on_twitch_eventsub_event(type: StringName, data: Dictionary) -> void:
	if type == "channel.follow":
		play("follow", "[b][color=red]%s[/color][/b] joined the community! Thank you!" % data.user_name)
	elif type == "channel.raid":
		play(
			"raid",
			"[b][color=red]%s[/color][/b] is raiding with [b][color=blue]%d[/color][/b] viewers!"
			% [data.from_broadcaster_user_name, data.viewers]
		)
	elif type == "channel.subscribe":
		play("sub", "[b][color=red]%s[/color][/b] subscribed as Tier %s! Thank you!" % [data.user_name, data.tier])
	elif type == "channel.subscription.gift":
		play("sub", "[b][color=red]%s[/color][/b] was gifted a Tier %s sub! Thank you!" % [data.user_name, data.tier])
	elif type == "channel.channel_points_custom_reward_redemption.add":
		var opt := TwitchGetCustomReward.Opt.create()
		opt.id = [data.reward.id]
		var reward: TwitchGetCustomReward.Response = await Twitch.broadcaster_api.get_custom_reward(opt, Twitch.chat.broadcaster_user.id)
		
		var image_url := reward.data[0].image.url_4x if reward.data[0].image != null else reward.data[0].default_image.url_4x
		var image := ImageTexture.create_from_image(Image.load_from_file(await Cache.cache(image_url)))
		var sprite_frames := SpriteFrames.new()
		sprite_frames.set_animation_speed("default", 1.0 / 8.0)
		sprite_frames.add_frame("default", image)
		
		var sound := preload("res://assets/alerts/redeem.wav")
		if data.reward.title == "\"Ok, let\'s go!\"":
			sound = preload("res://assets/sounds/ok_lets_go.wav")
		
		play_raw(
			sprite_frames,
			sound,
			(
				"[b][color=red]%s[/color][/b]" +
				" redeemed [b][color=blue]%s[/color][/b]" +
				" for [b][color=blue]%d[/color][/b] strings.\n%s"
			) % [
				data.user_name,
				data.reward.title,
				data.reward.cost,
				data.user_input,
			],
			3.0
		)
