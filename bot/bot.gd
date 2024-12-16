extends Node

var all_plushies := []
var plushies := {}
var groups := {}
var plushie_scene: PackedScene = preload("res://world/plushie/plushie.tscn")

var world: World
var twitch_bot: TwitchEvent
var twitch_broadcaster: TwitchEvent

var broadcaster_user_id: String
var qotd: String
var admins := PackedStringArray()
var simple_commands := {}
var redeem_sounds := {}
var rewards := {}

func strip_special_characters(args: String) -> String:
	var regex := RegEx.new()
	regex.compile("[^a-zA-Z0-9#+]")
	return regex.sub(args, "", true)

func log_message(message: String) -> void:
	print_rich("[color=lightblue][b][LOG][/b] %s[/color]" % message)
	#var log_file: FileAccess
	#if FileAccess.file_exists("user://bot_log.log"):
		#log_file = FileAccess.open("user://bot_log.log", FileAccess.READ_WRITE)
	#else:
		#log_file = FileAccess.open("user://bot_log.log", FileAccess.WRITE)
	#if log_file:
		#log_file.seek_end()
		#log_file.store_line(message)
		#log_file.close()

func setup() -> void:
	twitch_broadcaster.chat_message.connect(_on_chat_message)
	twitch_broadcaster.message_deleted.connect(_on_message_deleted)
	twitch_broadcaster.follow.connect(_on_follow)
	twitch_broadcaster.raid.connect(_on_raid)
	twitch_broadcaster.new_subscription.connect(_on_new_subscription)
	twitch_broadcaster.resubscription.connect(_on_resubscription)
	twitch_broadcaster.subscription_gift.connect(_on_subscription_gift)
	twitch_broadcaster.custom_point_reward_redeem.connect(_on_redeem)
	twitch_broadcaster.ad_break_start.connect(_on_ad_break_begin)
	
	var config_file := ConfigFile.new()
	if config_file.load("res://config.toml") != OK:
		print("Failed to load config file")
		return

	broadcaster_user_id = config_file.get_value("", "broadcaster_user_id")
	qotd = config_file.get_value("", "qotd")
	for admin: String in config_file.get_value("", "admins"):
		admins.append(admin.to_lower())

	for cmd: String in config_file.get_section_keys("simple_commands"):
		simple_commands[cmd] = config_file.get_value("simple_commands", cmd)

	for sound: String in config_file.get_section_keys("redeem_sounds"):
		redeem_sounds[strip_special_characters(sound)] = config_file.get_value("redeem_sounds", sound)

	Twitch.setup_twitch()
	Plushie.connect_heat()

	# * Load plushies
	var plushie_dir := DirAccess.open("res://assets/plushies")
	if plushie_dir:
		plushie_dir.list_dir_begin()
		var file_name := plushie_dir.get_next()
		while file_name != "":
			if plushie_dir.current_is_dir():
				all_plushies.append(file_name)

				var plushie_config := ConfigFile.new()
				if plushie_config.load("res://assets/plushies/" + file_name + "/config.toml") != OK:
					print("Failed to load config file for plushie '" + file_name + "', skipping")

				var names := [file_name]
				names.append_array(plushie_config.get_value("", "aliases", []))
				for i in range(names.size()): names[i] = strip_special_characters(names[i]).to_lower()
				plushies[file_name] = names

				for group: String in plushie_config.get_value("", "groups", []):
					group = strip_special_characters(group).to_lower()
					if !groups.has(group): groups[group] = []
					groups[group].append(file_name)
			file_name = plushie_dir.get_next()
	else:
		print("Plushie directory not found!")
	
	# Load redeems
	for reward: GGetCustomReward in twitch_broadcaster.get_custom_rewards():
		rewards[reward.id] = reward
	
	Twitch.monitor_ads()
#
func _on_message_deleted(message_deleted: GMessageDeleted) -> void:
	for message: ChatMessageLabel in world.chat_overlay.get_child(0).get_children():
		if message.data.message_id == message_deleted.message_id:
			message.queue_free()

func _on_follow(follow: GFollowData) -> void:
	world.alertbox.play("follow", "[b][color=red]%s[/color][/b] joined the community! Thank you!" % follow.user.name)

func _on_raid(raid: GRaid) -> void:
	world.alertbox.play(
		"raid",
		"[b][color=red]%s[/color][/b] is raiding with [b][color=blue]%d[/color][/b] viewers!"
		% [raid.from_broadcaster.name, raid.viewers]
	)

	twitch_bot.send_shoutout(raid.from_broadcaster.id)
	await get_tree().create_timer(3.0).timeout
	var plushie_id := find_plushie(raid.from_broadcaster.name)
	if !plushie_id.is_empty():
		for i in range(10):
			var plushie_instance: Plushie = plushie_scene.instantiate()
			plushie_instance.assign(plushie_id)
			plushie_instance.position_randomly(world.get_viewport_rect())
			world.plushies.add_child(plushie_instance)
			await world.get_tree().create_timer(1.0).timeout

func _on_new_subscription(sub: GNewSubscription) -> void:
	world.alertbox.play("sub", "[b][color=red]%s[/color][/b] subscribed as Tier %s! Thank you!" % [sub.user.name, sub.tier])

func _on_resubscription(sub: GResubscription) -> void:
	world.alertbox.play("sub", "[b][color=red]%s[/color][/b] resubscribed as Tier %s! They've been subscribed for %d months! Thank you!" % [sub.user.name, sub.tier, sub.streak_months])

func _on_subscription_gift(sub: GGift) -> void		:
	world.alertbox.play("sub", "[b][color=red]%s[/color][/b] was gifted a Tier %s sub! Thank you!" % [sub.user.name, sub.tier])

func _on_redeem(redeem: GCustomRewardRedeem) -> void:
	var title_id := strip_special_characters(redeem.reward.title).to_lower()
	if title_id == "plushieball":
		plushieball(false)
	elif title_id == "fire":
		if "fire" not in Store.viewer(redeem.user): Store.viewer(redeem.user).fire = 0
		Store.viewer(redeem.user).fire += 3
		Store.save()
	else:
		if redeem_sounds.has(title_id):
			world.sound_blaster.stream = load(redeem_sounds[title_id])
			world.sound_blaster.play()
			return
	var image_url: String = rewards[redeem.reward.id].image.url_4x
	var image := ImageTexture.create_from_image(Image.load_from_file(await Twitch.cache(image_url, ".png")))
	var sprite_frames := SpriteFrames.new()
	sprite_frames.add_animation("gif")
	sprite_frames.set_animation_speed("gif", 1.0 / 8.0)
	sprite_frames.add_frame("gif", image)
	world.alertbox.play_raw(
		sprite_frames,
		preload("res://assets/alerts/redeem.wav"),
		(
			"[b][color=red]%s[/color][/b]" +
			" redeemed [b][color=blue]%s[/color][/b]" +
			" for [b][color=blue]%d[/color][/b] strings.\n%s"
		) % [
			redeem.user.name,
			redeem.reward.title,
			redeem.reward.cost,
			redeem.user_input
		],
		3.0
	)

func _on_ad_break_begin(ad_break: GAdBreakBegin) -> void:
	twitch_bot.send_chat_message("%d second AD has started!" % ad_break.duration_seconds)
	await get_tree().create_timer(ad_break.duration_seconds).timeout
	twitch_bot.send_chat_message("The AD is done!")

func _on_chat_message(message: GMessageData) -> void:
	world.chat_overlay.add_message(message)
	if message.message.text[0] == '!':
		var raw_args: PackedStringArray = message.message.text.substr(1).split(' ', true, 1)
		var command: String = raw_args[0]
		var args: String = "" if raw_args.size() < 2 else raw_args[1]
		on_command(command, args, message)

func viewer_plushies(viewer_id: String) -> Array[Plushie]:
	var viewer_plushies: Array[Plushie] = []
	for plushie: Plushie in world.plushies.get_children():
		if plushie.viewer_id == viewer_id:
			viewer_plushies.append(plushie)
	return viewer_plushies

func attack_targets(target: String, viewer_id: String) -> Array[Plushie]:
	target = "" if target.is_empty() else find_plushie(target)
	var targets: Array[Plushie] = []
	for victim: Plushie in world.plushies.get_children():
		if victim.viewer_id == viewer_id: continue
		if victim.name != target && !target.is_empty(): continue
		targets.append(victim)
	return targets

func closest_plushie(plushies_list: Array[Plushie], to: Vector2) -> Plushie:
	var closest: Plushie = null
	for plushie in plushies_list:
		if closest == null || plushie.soft_body.get_bones_center_position().distance_squared_to(to) < closest.soft_body.get_bones_center_position().distance_squared_to(to):
			closest = plushie
	return closest

# ******************************************************************** On Command
func on_command(command: String, args: String, message: GMessageData) -> void:
	var admin: bool = admins.has(message.chatter.login.to_lower())
	if command == "plushie":
		if !admin && timeout(message.chatter.login, "plushies", 10.0): return
		var args_arr = args.split("!")
		var plushie_name = find_plushie(args_arr[0])
		if plushie_name.is_empty():
			if timeouts.has("plushies"): timeouts["plushies"].erase(message.chatter.login)
			return

		var bangs := Array(args_arr).map(func (bang): return bang.strip_edges()) if args_arr.size() > 1 else []

		var plushie_instance: Plushie = plushie_scene.instantiate()
		plushie_instance.assign(plushie_name)
		plushie_instance.position_randomly(world.get_viewport_rect())
		plushie_instance.viewer_id = message.chatter.id
		
		if "fire" in bangs && "fire" in Store.viewer(message.chatter) && Store.viewer(message.chatter).fire > 0:
			Store.viewer(message.chatter).fire -= 1
			Store.save()
			plushie_instance.has_fire = true
		
		world.plushies.add_child(plushie_instance)
	elif command == "pick":
		if !admin && timeout(message.chatter.login, "plushies", 10.0): return

		args = strip_special_characters(args).to_lower()
		if !groups.has(args):
			if timeouts.has("plushies"): timeouts["plushies"].erase(message.chatter.login)
			return

		var plushie_instance: Plushie = plushie_scene.instantiate()
		plushie_instance.assign(groups[args].pick_random())
		plushie_instance.position_randomly(world.get_viewport_rect())
		plushie_instance.viewer_id = message.chatter.id
		world.plushies.add_child(plushie_instance)
	elif command == "readchat":
		world.sound_blaster.stream = preload("res://assets/readchat.wav")
		world.sound_blaster.play()
	elif command == "qotd":
		twitch_bot.send_chat_message("@%s %s" % [message.chatter.login, qotd])
	elif command == ">":
		Uiua.execute(args, world.get_node(^"%Terminal"))
	elif command == "lurk":
		twitch_bot.send_chat_message("Have a nice lurk, @%s. Lurkers are a power of Software and Game development streams!" % [message.chatter.login])
	elif command == "unlurk":
		twitch_bot.send_chat_message("Welcome back, @%s!" % [message.chatter.login])
	elif command == "add_force":
		var force_str := args.split(" ")
		if force_str.size() != 2: return
		var force := Vector2(float(force_str[0]), float(force_str[1])).limit_length(5.0) * 20000
		for plushie: Plushie in viewer_plushies(message.chatter.id):
			plushie.soft_body.apply_force(force)
	elif command == "punch":
		var target: Plushie = attack_targets(args, message.chatter.id).pick_random()
		if target != null:
			var target_center := target.soft_body.get_bones_center_position()
			var plushie := closest_plushie(viewer_plushies(message.chatter.id), target_center)
			if plushie != null: plushie.attack(target)
	elif command == "fire":
		var target: Plushie = attack_targets(args, message.chatter.id).pick_random()
		if target != null:
			var target_center := target.soft_body.get_bones_center_position()
			var plushie := closest_plushie(viewer_plushies(message.chatter.id).filter(func (plushie): return plushie.has_fire), target_center)
			if plushie != null:
				var fire_pos := plushie.soft_body.get_bones_center_position() + Vector2(0, -200)
				var impulse: Vector2 = (target_center - fire_pos) * 3
				var projectile: RigidBody2D = preload("res://world/plushie/projectiles/fireball.tscn").instantiate()
				projectile.position = fire_pos
				projectile.viewer_id = message.chatter.id
				projectile.apply_impulse(impulse)
				world.add_child(projectile)
	elif command == "put_out":
		var plushie_name := find_plushie(args)
		for plushie in viewer_plushies(message.chatter.id):
			if plushie.name == plushie_name: plushie.put_out()
	else:
		for cmd: String in simple_commands.keys():
			if command == cmd:
				twitch_bot.send_chat_message("@%s %s" % [message.chatter.login, simple_commands[cmd]])

var timeouts := {}
func timeout(author: String, topic: String, time: float) -> bool:
	if !timeouts.has(topic): timeouts[topic] = {}
	if timeouts[topic].has(author) && timeouts[topic][author].time_left > 0.0: return true
	timeouts[topic][author] = world.get_tree().create_timer(time)
	return false

func find_plushie(args: String) -> String:
	var plushie_id := ""
	args = strip_special_characters(args).to_lower()
	if args.is_empty():
		plushie_id = all_plushies.pick_random()
	else:
		var best_score := 0
		for id: String in plushies.keys():
			var score := 0
			for plushie_name: String in plushies[id]:
				if args.contains(plushie_name):
					score += plushie_name.length()
			if score > best_score:
				plushie_id = id
				best_score = score
	return plushie_id

func random_plushie() -> Plushie:
	var plushie_instance: Plushie = plushie_scene.instantiate()
	plushie_instance.assign(plushies.keys().pick_random())
	plushie_instance.position_randomly(world.get_viewport_rect())
	world.plushies.add_child(plushie_instance)
	return plushie_instance

func plushieball(tournament: bool) -> void:
	if world.has_node(^"Court"):
		world.get_node(^"Court").queue_free()
	
	var court: Court = preload("res://world/plushieball/court.tscn").instantiate()
	court.plushieball(tournament)
	world.add_child(court)
