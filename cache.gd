extends Node

func download(url: String, file_path: String) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.set_download_file(file_path)
	http.request(url)
	await http.request_completed

func cache(url: String, ext: String = "") -> String:
	var file_path := "user://cache/%s" % [url.replace("http://", "").replace("https://", "")]
	if ext != null: file_path += ext
	if FileAccess.file_exists(file_path): return file_path
	DirAccess.make_dir_recursive_absolute(file_path.substr(0, file_path.rfind('/')))
	await download(url, file_path)
	return file_path
