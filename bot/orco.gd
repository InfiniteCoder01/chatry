class_name OrCo

static func execute(code: String, terminal: RichTextLabel) -> void:
	terminal.clear()
	terminal.push_mono()

	var print_terminal := func print_terminal(text: String) -> void:
		# print_rich(text)
		terminal.append_text(text)
		terminal.newline()
		if terminal.get_total_character_count() > 10000: terminal.clear()

	var process := ProcessNode.new();
	process.cmd = "docker";
	process.args = PackedStringArray([
		"run",
		"--cpus", "0.5", "--memory", "20m", "--network", "none",
		"--read-only",
		"-v", "/mnt/Twitch:/home",
		"-v", "/mnt/Dev/Bots/Platforms/chatry/container/orco:/orco:ro",
		"-i", "twitch-linux", "/orco/compile.sh"
	]);
	process.stdout.connect(
		func _on_stdout(data: PackedByteArray) -> void:
			var output := data.get_string_from_utf8()
			var pos := output.rfind("!clear\r\n")
			if pos != -1:
				terminal.clear()
				output = output.substr(pos + 8)
			print_terminal.call(output)
	)
	process.stderr.connect(
		func _on_stderr(data: PackedByteArray) -> void:
			print_terminal.call("[color=yellow]%s[/color]" % data.get_string_from_utf8())
	)
	process.finished.connect(
		func _on_finised(_exit_code: int) -> void:
			terminal.remove_child(process)
			process.queue_free()
	)

	process.start()
	terminal.add_child(process)
	process.write_stdin(code.to_utf8_buffer())
	process.eof_stdin()
