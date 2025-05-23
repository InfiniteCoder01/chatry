@tool
extends EditorInspectorPlugin

var token_info_scene: PackedScene = preload("res://addons/twitcher/lib/oOuch/oauth_token_info.tscn")

func _can_handle(object: Object) -> bool:
	return object is OAuthToken


func _parse_begin(object: Object) -> void:
	var token_info = token_info_scene.instantiate()
	token_info.token = object
	add_custom_control(token_info)
