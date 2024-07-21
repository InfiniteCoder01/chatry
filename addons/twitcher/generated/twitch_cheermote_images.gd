@tool
extends RefCounted

# CLASS GOT AUTOGENERATED DON'T CHANGE MANUALLY. CHANGES CAN BE OVERWRITTEN EASILY.

class_name TwitchCheermoteImages

## No description available
var light: TwitchCheermoteImageTheme;
## No description available
var dark: TwitchCheermoteImageTheme;

static func from_json(d: Dictionary) -> TwitchCheermoteImages:
	var result = TwitchCheermoteImages.new();
	if d.has("light") && d["light"] != null:
		result.light = TwitchCheermoteImageTheme.from_json(d["light"]);
	if d.has("dark") && d["dark"] != null:
		result.dark = TwitchCheermoteImageTheme.from_json(d["dark"]);
	return result;

func to_dict() -> Dictionary:
	var d: Dictionary = {};
	if light != null:
		d["light"] = light.to_dict();
	if dark != null:
		d["dark"] = dark.to_dict();
	return d;

func to_json() -> String:
	return JSON.stringify(to_dict());
