@tool
extends TwitchData

# CLASS GOT AUTOGENERATED DON'T CHANGE MANUALLY. CHANGES CAN BE OVERWRITTEN EASILY.

class_name TwitchGetStreamKey
	


## 
## #/components/schemas/GetStreamKeyResponse
class Response extends TwitchData:

	## A list that contains the channel’s stream key.
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
	


## A list that contains the channel’s stream key.
## #/components/schemas/GetStreamKeyResponse/Data
class ResponseData extends TwitchData:

	## The channel’s stream key.
	@export var stream_key: String:
		set(val): 
			stream_key = val
			track_data(&"stream_key", val)
	
	
	
	## Constructor with all required fields.
	static func create(_stream_key: String) -> ResponseData:
		var response_data: ResponseData = ResponseData.new()
		response_data.stream_key = _stream_key
		return response_data
	
	
	static func from_json(d: Dictionary) -> ResponseData:
		var result: ResponseData = ResponseData.new()
		if d.get("stream_key", null) != null:
			result.stream_key = d["stream_key"]
		return result
	