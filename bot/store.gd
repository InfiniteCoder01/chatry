extends Node

const STORE_PATH := "/mnt/D/Channel/store.json"
var store := { viewers = {} }

func _ready() -> void:
	var json := JSON.new()
	var error := json.parse(FileAccess.open(STORE_PATH, FileAccess.READ).get_as_text())
	if error == OK: store = json.data
	else: print("Failed to load store: ", error)

func viewer(user: GUser) -> Variant:
	if user.id not in store.viewers:
		store.viewers[user.id] = { name = user.name }
	return store.viewers[user.id]

func save() -> void:
	var file := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(store, "   "))
