@tool
extends TwitchData

# CLASS GOT AUTOGENERATED DON'T CHANGE MANUALLY. CHANGES CAN BE OVERWRITTEN EASILY.

class_name TwitchUpdateRedemptionStatus
	


## 
## #/components/schemas/UpdateRedemptionStatusBody
class Body extends TwitchData:

	## The status to set the redemption to. Possible values are:  
	##   
	## * CANCELED
	## * FULFILLED
	##   
	## Setting the status to CANCELED refunds the user’s channel points.
	@export var status: String:
		set(val): 
			status = val
			track_data(&"status", val)
	var response: BufferedHTTPClient.ResponseData
	
	
	## Constructor with all required fields.
	static func create(_status: String) -> Body:
		var body: Body = Body.new()
		body.status = _status
		return body
	
	
	static func from_json(d: Dictionary) -> Body:
		var result: Body = Body.new()
		if d.get("status", null) != null:
			result.status = d["status"]
		return result
	


## 
## #/components/schemas/UpdateRedemptionStatusResponse
class Response extends TwitchData:

	## The list contains the single redemption that you updated.
	@export var data: Array[TwitchCustomRewardRedemption]:
		set(val): 
			data = val
			track_data(&"data", val)
	var response: BufferedHTTPClient.ResponseData
	
	
	## Constructor with all required fields.
	static func create(_data: Array[TwitchCustomRewardRedemption]) -> Response:
		var response: Response = Response.new()
		response.data = _data
		return response
	
	
	static func from_json(d: Dictionary) -> Response:
		var result: Response = Response.new()
		if d.get("data", null) != null:
			for value in d["data"]:
				result.data.append(TwitchCustomRewardRedemption.from_json(value))
		return result
	