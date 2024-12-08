class_name Uiua

static func execute(code: String, terminal: RichTextLabel) -> void:
	code = r'''
&fde "tmpim"
&fmd "tmpim"
ImsCvt = try($"_.png" now img "png")($"_.gif" now gif 20)
Ims    = $"!ims tmpim/_" &fwa $"tmpim/_" on: ImsCvt
''' + code

	terminal.clear()
	terminal.push_mono()

	var print_terminal := func print_terminal(text: String) -> void:
		#print_rich(text)
		if text == "!clear":
			terminal.clear()
		elif text.begins_with("\"!ims "):
			var filename := "/mnt/Twitch/" + text.substr(6, text.length() - 7)
			if filename.ends_with(".gif"):
				terminal.add_image(GifManager.animated_texture_from_file(filename))
			else:
				terminal.add_image(ImageTexture.create_from_image(Image.load_from_file(filename)))
			terminal.newline()
		else:
			terminal.append_text(text)
			terminal.newline()
			if terminal.get_total_character_count() > 10000: terminal.clear()

	var process := ProcessNode.new()
	process.cmd = "docker"
	process.args = PackedStringArray([
		"run",
		"--cpus", "0.5", "--memory", "20m", "--network", "none",
		"--read-only",
		"-v", "/mnt/Twitch:/home",
		"--workdir", "/home",
		"-i", "twitch-linux",
		"timeout", "5",
		"uiua", "eval", code
	])
	process.stdout.connect(
		func _on_stdout(data: PackedByteArray) -> void:
			var output := data.get_string_from_utf8().split("\n")
			for line in output: print_terminal.call(line)
	)
	process.stderr.connect(
		func _on_stderr(data: PackedByteArray) -> void:
			terminal.push_color(Color.YELLOW)
			terminal.add_text(data.get_string_from_utf8())
			terminal.pop()
			if terminal.get_total_character_count() > 10000: terminal.clear()
	)
	process.finished.connect(
		func _on_finised(_exit_code: int) -> void:
			terminal.remove_child(process)
			process.queue_free()
	)

	process.start()
	terminal.add_child(process)
