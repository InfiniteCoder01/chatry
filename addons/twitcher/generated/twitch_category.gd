@tool
extends TwitchData

# CLASS GOT AUTOGENERATED DON'T CHANGE MANUALLY. CHANGES CAN BE OVERWRITTEN EASILY.

## 
## #/components/schemas/Category
class_name TwitchCategory
	
## A URL to an image of the game’s box art or streaming category.
@export var box_art_url: String:
	set(val): 
		box_art_url = val
		track_data(&"box_art_url", val)

## The name of the game or category.
@export var name: String:
	set(val): 
		name = val
		track_data(&"name", val)

## An ID that uniquely identifies the game or category.
@export var id: String:
	set(val): 
		id = val
		track_data(&"id", val)
var response: BufferedHTTPClient.ResponseData


## Constructor with all required fields.
static func create(_box_art_url: String, _name: String, _id: String) -> TwitchCategory:
	var twitch_category: TwitchCategory = TwitchCategory.new()
	twitch_category.box_art_url = _box_art_url
	twitch_category.name = _name
	twitch_category.id = _id
	return twitch_category


static func from_json(d: Dictionary) -> TwitchCategory:
	var result: TwitchCategory = TwitchCategory.new()
	if d.get("box_art_url", null) != null:
		result.box_art_url = d["box_art_url"]
	if d.get("name", null) != null:
		result.name = d["name"]
	if d.get("id", null) != null:
		result.id = d["id"]
	return result
