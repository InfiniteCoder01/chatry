@tool
extends TwitchData

# CLASS GOT AUTOGENERATED DON'T CHANGE MANUALLY. CHANGES CAN BE OVERWRITTEN EASILY.

## 
## #/components/schemas/CustomReward
class_name TwitchCustomReward
	
## The ID that uniquely identifies the broadcaster.
@export var broadcaster_id: String:
	set(val): 
		broadcaster_id = val
		track_data(&"broadcaster_id", val)

## The broadcaster’s login name.
@export var broadcaster_login: String:
	set(val): 
		broadcaster_login = val
		track_data(&"broadcaster_login", val)

## The broadcaster’s display name.
@export var broadcaster_name: String:
	set(val): 
		broadcaster_name = val
		track_data(&"broadcaster_name", val)

## The ID that uniquely identifies this custom reward.
@export var id: String:
	set(val): 
		id = val
		track_data(&"id", val)

## The title of the reward.
@export var title: String:
	set(val): 
		title = val
		track_data(&"title", val)

## The prompt shown to the viewer when they redeem the reward if user input is required. See the `is_user_input_required` field.
@export var prompt: String:
	set(val): 
		prompt = val
		track_data(&"prompt", val)

## The cost of the reward in Channel Points.
@export var cost: int:
	set(val): 
		cost = val
		track_data(&"cost", val)

## A set of custom images for the reward. This field is **null** if the broadcaster didn’t upload images.
@export var image: TwitchImage:
	set(val): 
		image = val
		track_data(&"image", val)

## A set of default images for the reward.
@export var default_image: DefaultImage:
	set(val): 
		default_image = val
		track_data(&"default_image", val)

## The background color to use for the reward. The color is in Hex format (for example, #00E5CB).
@export var background_color: String:
	set(val): 
		background_color = val
		track_data(&"background_color", val)

## A Boolean value that determines whether the reward is enabled. Is **true** if enabled; otherwise, **false**. Disabled rewards aren’t shown to the user.
@export var is_enabled: bool:
	set(val): 
		is_enabled = val
		track_data(&"is_enabled", val)

## A Boolean value that determines whether the user must enter information when they redeem the reward. Is **true** if the user is prompted.
@export var is_user_input_required: bool:
	set(val): 
		is_user_input_required = val
		track_data(&"is_user_input_required", val)

## The settings used to determine whether to apply a maximum to the number of redemptions allowed per live stream.
@export var max_per_stream_setting: MaxPerStreamSetting:
	set(val): 
		max_per_stream_setting = val
		track_data(&"max_per_stream_setting", val)

## The settings used to determine whether to apply a maximum to the number of redemptions allowed per user per live stream.
@export var max_per_user_per_stream_setting: MaxPerUserPerStreamSetting:
	set(val): 
		max_per_user_per_stream_setting = val
		track_data(&"max_per_user_per_stream_setting", val)

## The settings used to determine whether to apply a cooldown period between redemptions and the length of the cooldown.
@export var global_cooldown_setting: GlobalCooldownSetting:
	set(val): 
		global_cooldown_setting = val
		track_data(&"global_cooldown_setting", val)

## A Boolean value that determines whether the reward is currently paused. Is **true** if the reward is paused. Viewers can’t redeem paused rewards.
@export var is_paused: bool:
	set(val): 
		is_paused = val
		track_data(&"is_paused", val)

## A Boolean value that determines whether the reward is currently in stock. Is **true** if the reward is in stock. Viewers can’t redeem out of stock rewards.
@export var is_in_stock: bool:
	set(val): 
		is_in_stock = val
		track_data(&"is_in_stock", val)

## A Boolean value that determines whether redemptions should be set to FULFILLED status immediately when a reward is redeemed. If **false**, status is set to UNFULFILLED and follows the normal request queue process.
@export var should_redemptions_skip_request_queue: bool:
	set(val): 
		should_redemptions_skip_request_queue = val
		track_data(&"should_redemptions_skip_request_queue", val)

## The number of redemptions redeemed during the current live stream. The number counts against the `max_per_stream_setting` limit. This field is **null** if the broadcaster’s stream isn’t live or _max\_per\_stream\_setting_ isn’t enabled.
@export var redemptions_redeemed_current_stream: int:
	set(val): 
		redemptions_redeemed_current_stream = val
		track_data(&"redemptions_redeemed_current_stream", val)

## The timestamp of when the cooldown period expires. Is **null** if the reward isn’t in a cooldown state. See the `global_cooldown_setting` field.
@export var cooldown_expires_at: String:
	set(val): 
		cooldown_expires_at = val
		track_data(&"cooldown_expires_at", val)
var response: BufferedHTTPClient.ResponseData


## Constructor with all required fields.
static func create(_broadcaster_id: String, _broadcaster_login: String, _broadcaster_name: String, _id: String, _title: String, _prompt: String, _cost: int, _image: TwitchImage, _default_image: DefaultImage, _background_color: String, _is_enabled: bool, _is_user_input_required: bool, _max_per_stream_setting: MaxPerStreamSetting, _max_per_user_per_stream_setting: MaxPerUserPerStreamSetting, _global_cooldown_setting: GlobalCooldownSetting, _is_paused: bool, _is_in_stock: bool, _should_redemptions_skip_request_queue: bool, _redemptions_redeemed_current_stream: int, _cooldown_expires_at: String) -> TwitchCustomReward:
	var twitch_custom_reward: TwitchCustomReward = TwitchCustomReward.new()
	twitch_custom_reward.broadcaster_id = _broadcaster_id
	twitch_custom_reward.broadcaster_login = _broadcaster_login
	twitch_custom_reward.broadcaster_name = _broadcaster_name
	twitch_custom_reward.id = _id
	twitch_custom_reward.title = _title
	twitch_custom_reward.prompt = _prompt
	twitch_custom_reward.cost = _cost
	twitch_custom_reward.image = _image
	twitch_custom_reward.default_image = _default_image
	twitch_custom_reward.background_color = _background_color
	twitch_custom_reward.is_enabled = _is_enabled
	twitch_custom_reward.is_user_input_required = _is_user_input_required
	twitch_custom_reward.max_per_stream_setting = _max_per_stream_setting
	twitch_custom_reward.max_per_user_per_stream_setting = _max_per_user_per_stream_setting
	twitch_custom_reward.global_cooldown_setting = _global_cooldown_setting
	twitch_custom_reward.is_paused = _is_paused
	twitch_custom_reward.is_in_stock = _is_in_stock
	twitch_custom_reward.should_redemptions_skip_request_queue = _should_redemptions_skip_request_queue
	twitch_custom_reward.redemptions_redeemed_current_stream = _redemptions_redeemed_current_stream
	twitch_custom_reward.cooldown_expires_at = _cooldown_expires_at
	return twitch_custom_reward


static func from_json(d: Dictionary) -> TwitchCustomReward:
	var result: TwitchCustomReward = TwitchCustomReward.new()
	if d.get("broadcaster_id", null) != null:
		result.broadcaster_id = d["broadcaster_id"]
	if d.get("broadcaster_login", null) != null:
		result.broadcaster_login = d["broadcaster_login"]
	if d.get("broadcaster_name", null) != null:
		result.broadcaster_name = d["broadcaster_name"]
	if d.get("id", null) != null:
		result.id = d["id"]
	if d.get("title", null) != null:
		result.title = d["title"]
	if d.get("prompt", null) != null:
		result.prompt = d["prompt"]
	if d.get("cost", null) != null:
		result.cost = d["cost"]
	if d.get("image", null) != null:
		result.image = TwitchImage.from_json(d["image"])
	if d.get("default_image", null) != null:
		result.default_image = DefaultImage.from_json(d["default_image"])
	if d.get("background_color", null) != null:
		result.background_color = d["background_color"]
	if d.get("is_enabled", null) != null:
		result.is_enabled = d["is_enabled"]
	if d.get("is_user_input_required", null) != null:
		result.is_user_input_required = d["is_user_input_required"]
	if d.get("max_per_stream_setting", null) != null:
		result.max_per_stream_setting = MaxPerStreamSetting.from_json(d["max_per_stream_setting"])
	if d.get("max_per_user_per_stream_setting", null) != null:
		result.max_per_user_per_stream_setting = MaxPerUserPerStreamSetting.from_json(d["max_per_user_per_stream_setting"])
	if d.get("global_cooldown_setting", null) != null:
		result.global_cooldown_setting = GlobalCooldownSetting.from_json(d["global_cooldown_setting"])
	if d.get("is_paused", null) != null:
		result.is_paused = d["is_paused"]
	if d.get("is_in_stock", null) != null:
		result.is_in_stock = d["is_in_stock"]
	if d.get("should_redemptions_skip_request_queue", null) != null:
		result.should_redemptions_skip_request_queue = d["should_redemptions_skip_request_queue"]
	if d.get("redemptions_redeemed_current_stream", null) != null:
		result.redemptions_redeemed_current_stream = d["redemptions_redeemed_current_stream"]
	if d.get("cooldown_expires_at", null) != null:
		result.cooldown_expires_at = d["cooldown_expires_at"]
	return result



## A set of custom images for the reward. This field is **null** if the broadcaster didn’t upload images.
## #/components/schemas/CustomReward/Image
class TwitchImage extends TwitchData:

	## The URL to a small version of the image.
	@export var url_1x: String:
		set(val): 
			url_1x = val
			track_data(&"url_1x", val)
	
	## The URL to a medium version of the image.
	@export var url_2x: String:
		set(val): 
			url_2x = val
			track_data(&"url_2x", val)
	
	## The URL to a large version of the image.
	@export var url_4x: String:
		set(val): 
			url_4x = val
			track_data(&"url_4x", val)
	
	
	
	## Constructor with all required fields.
	static func create(_url_1x: String, _url_2x: String, _url_4x: String) -> TwitchImage:
		var twitch_image: TwitchImage = TwitchImage.new()
		twitch_image.url_1x = _url_1x
		twitch_image.url_2x = _url_2x
		twitch_image.url_4x = _url_4x
		return twitch_image
	
	
	static func from_json(d: Dictionary) -> TwitchImage:
		var result: TwitchImage = TwitchImage.new()
		if d.get("url_1x", null) != null:
			result.url_1x = d["url_1x"]
		if d.get("url_2x", null) != null:
			result.url_2x = d["url_2x"]
		if d.get("url_4x", null) != null:
			result.url_4x = d["url_4x"]
		return result
	


## A set of default images for the reward.
## #/components/schemas/CustomReward/DefaultImage
class DefaultImage extends TwitchData:

	## The URL to a small version of the image.
	@export var url_1x: String:
		set(val): 
			url_1x = val
			track_data(&"url_1x", val)
	
	## The URL to a medium version of the image.
	@export var url_2x: String:
		set(val): 
			url_2x = val
			track_data(&"url_2x", val)
	
	## The URL to a large version of the image.
	@export var url_4x: String:
		set(val): 
			url_4x = val
			track_data(&"url_4x", val)
	
	
	
	## Constructor with all required fields.
	static func create(_url_1x: String, _url_2x: String, _url_4x: String) -> DefaultImage:
		var default_image: DefaultImage = DefaultImage.new()
		default_image.url_1x = _url_1x
		default_image.url_2x = _url_2x
		default_image.url_4x = _url_4x
		return default_image
	
	
	static func from_json(d: Dictionary) -> DefaultImage:
		var result: DefaultImage = DefaultImage.new()
		if d.get("url_1x", null) != null:
			result.url_1x = d["url_1x"]
		if d.get("url_2x", null) != null:
			result.url_2x = d["url_2x"]
		if d.get("url_4x", null) != null:
			result.url_4x = d["url_4x"]
		return result
	


## The settings used to determine whether to apply a maximum to the number of redemptions allowed per live stream.
## #/components/schemas/CustomReward/MaxPerStreamSetting
class MaxPerStreamSetting extends TwitchData:

	## A Boolean value that determines whether the reward applies a limit on the number of redemptions allowed per live stream. Is **true** if the reward applies a limit.
	@export var is_enabled: bool:
		set(val): 
			is_enabled = val
			track_data(&"is_enabled", val)
	
	## The maximum number of redemptions allowed per live stream.
	@export var max_per_stream: int:
		set(val): 
			max_per_stream = val
			track_data(&"max_per_stream", val)
	
	
	
	## Constructor with all required fields.
	static func create(_is_enabled: bool, _max_per_stream: int) -> MaxPerStreamSetting:
		var max_per_stream_setting: MaxPerStreamSetting = MaxPerStreamSetting.new()
		max_per_stream_setting.is_enabled = _is_enabled
		max_per_stream_setting.max_per_stream = _max_per_stream
		return max_per_stream_setting
	
	
	static func from_json(d: Dictionary) -> MaxPerStreamSetting:
		var result: MaxPerStreamSetting = MaxPerStreamSetting.new()
		if d.get("is_enabled", null) != null:
			result.is_enabled = d["is_enabled"]
		if d.get("max_per_stream", null) != null:
			result.max_per_stream = d["max_per_stream"]
		return result
	


## The settings used to determine whether to apply a maximum to the number of redemptions allowed per user per live stream.
## #/components/schemas/CustomReward/MaxPerUserPerStreamSetting
class MaxPerUserPerStreamSetting extends TwitchData:

	## A Boolean value that determines whether the reward applies a limit on the number of redemptions allowed per user per live stream. Is **true** if the reward applies a limit.
	@export var is_enabled: bool:
		set(val): 
			is_enabled = val
			track_data(&"is_enabled", val)
	
	## The maximum number of redemptions allowed per user per live stream.
	@export var max_per_user_per_stream: int:
		set(val): 
			max_per_user_per_stream = val
			track_data(&"max_per_user_per_stream", val)
	
	
	
	## Constructor with all required fields.
	static func create(_is_enabled: bool, _max_per_user_per_stream: int) -> MaxPerUserPerStreamSetting:
		var max_per_user_per_stream_setting: MaxPerUserPerStreamSetting = MaxPerUserPerStreamSetting.new()
		max_per_user_per_stream_setting.is_enabled = _is_enabled
		max_per_user_per_stream_setting.max_per_user_per_stream = _max_per_user_per_stream
		return max_per_user_per_stream_setting
	
	
	static func from_json(d: Dictionary) -> MaxPerUserPerStreamSetting:
		var result: MaxPerUserPerStreamSetting = MaxPerUserPerStreamSetting.new()
		if d.get("is_enabled", null) != null:
			result.is_enabled = d["is_enabled"]
		if d.get("max_per_user_per_stream", null) != null:
			result.max_per_user_per_stream = d["max_per_user_per_stream"]
		return result
	


## The settings used to determine whether to apply a cooldown period between redemptions and the length of the cooldown.
## #/components/schemas/CustomReward/GlobalCooldownSetting
class GlobalCooldownSetting extends TwitchData:

	## A Boolean value that determines whether to apply a cooldown period. Is **true** if a cooldown period is enabled.
	@export var is_enabled: bool:
		set(val): 
			is_enabled = val
			track_data(&"is_enabled", val)
	
	## The cooldown period, in seconds.
	@export var global_cooldown_seconds: int:
		set(val): 
			global_cooldown_seconds = val
			track_data(&"global_cooldown_seconds", val)
	
	
	
	## Constructor with all required fields.
	static func create(_is_enabled: bool, _global_cooldown_seconds: int) -> GlobalCooldownSetting:
		var global_cooldown_setting: GlobalCooldownSetting = GlobalCooldownSetting.new()
		global_cooldown_setting.is_enabled = _is_enabled
		global_cooldown_setting.global_cooldown_seconds = _global_cooldown_seconds
		return global_cooldown_setting
	
	
	static func from_json(d: Dictionary) -> GlobalCooldownSetting:
		var result: GlobalCooldownSetting = GlobalCooldownSetting.new()
		if d.get("is_enabled", null) != null:
			result.is_enabled = d["is_enabled"]
		if d.get("global_cooldown_seconds", null) != null:
			result.global_cooldown_seconds = d["global_cooldown_seconds"]
		return result
	