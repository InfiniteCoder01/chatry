@tool
extends TwitchData

# CLASS GOT AUTOGENERATED DON'T CHANGE MANUALLY. CHANGES CAN BE OVERWRITTEN EASILY.

class_name TwitchStartCommercial
	


## 
## #/components/schemas/StartCommercialBody
class Body extends TwitchData:

	## The ID of the partner or affiliate broadcaster that wants to run the commercial. This ID must match the user ID found in the OAuth token.
	@export var broadcaster_id: String:
		set(val): 
			broadcaster_id = val
			track_data(&"broadcaster_id", val)
	
	## The length of the commercial to run, in seconds. Twitch tries to serve a commercial that’s the requested length, but it may be shorter or longer. The maximum length you should request is 180 seconds.
	@export var length: int:
		set(val): 
			length = val
			track_data(&"length", val)
	var response: BufferedHTTPClient.ResponseData
	
	
	## Constructor with all required fields.
	static func create(_broadcaster_id: String, _length: int) -> Body:
		var body: Body = Body.new()
		body.broadcaster_id = _broadcaster_id
		body.length = _length
		return body
	
	
	static func from_json(d: Dictionary) -> Body:
		var result: Body = Body.new()
		if d.get("broadcaster_id", null) != null:
			result.broadcaster_id = d["broadcaster_id"]
		if d.get("length", null) != null:
			result.length = d["length"]
		return result
	


## 
## #/components/schemas/StartCommercialResponse
class Response extends TwitchData:

	## An array that contains a single object with the status of your start commercial request.
	@export var data: Array[ResponseData]:
		set(val): 
			data = val
			track_data(&"data", val)
	var response: BufferedHTTPClient.ResponseData
	
	
	## Constructor with all required fields.
	static func create(_data: Array[ResponseData]) -> Response:
		var response: Response = Response.new()
		response.data = _data
		return response
	
	
	static func from_json(d: Dictionary) -> Response:
		var result: Response = Response.new()
		if d.get("data", null) != null:
			for value in d["data"]:
				result.data.append(ResponseData.from_json(value))
		return result
	


## An array that contains a single object with the status of your start commercial request.
## #/components/schemas/StartCommercialResponse/Data
class ResponseData extends TwitchData:

	## The length of the commercial you requested. If you request a commercial that’s longer than 180 seconds, the API uses 180 seconds.
	@export var length: int:
		set(val): 
			length = val
			track_data(&"length", val)
	
	## A message that indicates whether Twitch was able to serve an ad.
	@export var message: String:
		set(val): 
			message = val
			track_data(&"message", val)
	
	## The number of seconds you must wait before running another commercial.
	@export var retry_after: int:
		set(val): 
			retry_after = val
			track_data(&"retry_after", val)
	
	
	
	## Constructor with all required fields.
	static func create(_length: int, _message: String, _retry_after: int) -> ResponseData:
		var response_data: ResponseData = ResponseData.new()
		response_data.length = _length
		response_data.message = _message
		response_data.retry_after = _retry_after
		return response_data
	
	
	static func from_json(d: Dictionary) -> ResponseData:
		var result: ResponseData = ResponseData.new()
		if d.get("length", null) != null:
			result.length = d["length"]
		if d.get("message", null) != null:
			result.message = d["message"]
		if d.get("retry_after", null) != null:
			result.retry_after = d["retry_after"]
		return result
	