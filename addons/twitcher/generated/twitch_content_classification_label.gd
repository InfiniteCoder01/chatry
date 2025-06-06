@tool
extends TwitchData

# CLASS GOT AUTOGENERATED DON'T CHANGE MANUALLY. CHANGES CAN BE OVERWRITTEN EASILY.

## 
## #/components/schemas/ContentClassificationLabel
class_name TwitchContentClassificationLabel
	
## Unique identifier for the CCL.
@export var id: String:
	set(val): 
		id = val
		track_data(&"id", val)

## Localized description of the CCL.
@export var description: String:
	set(val): 
		description = val
		track_data(&"description", val)

## Localized name of the CCL.
@export var name: String:
	set(val): 
		name = val
		track_data(&"name", val)
var response: BufferedHTTPClient.ResponseData


## Constructor with all required fields.
static func create(_id: String, _description: String, _name: String) -> TwitchContentClassificationLabel:
	var twitch_content_classification_label: TwitchContentClassificationLabel = TwitchContentClassificationLabel.new()
	twitch_content_classification_label.id = _id
	twitch_content_classification_label.description = _description
	twitch_content_classification_label.name = _name
	return twitch_content_classification_label


static func from_json(d: Dictionary) -> TwitchContentClassificationLabel:
	var result: TwitchContentClassificationLabel = TwitchContentClassificationLabel.new()
	if d.get("id", null) != null:
		result.id = d["id"]
	if d.get("description", null) != null:
		result.description = d["description"]
	if d.get("name", null) != null:
		result.name = d["name"]
	return result
