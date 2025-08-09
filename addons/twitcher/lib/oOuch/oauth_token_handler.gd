@icon("./security-icon.svg")
@tool
extends Node

class_name OAuthTokenHandler

const OAuthHTTPClient = preload("res://addons/twitcher/lib/http/buffered_http_client.gd")
const OAuthDeviceCodeResponse = preload("./oauth_device_code_response.gd")

## Handles refreshing and resolving access and refresh tokens.

const HEADERS = {
	"Accept": "*/*",
	"Content-Type": "application/x-www-form-urlencoded"
}
const SECONDS_TO_CHECK_EARLIER = 60

## Called when new access token is available
signal token_resolved(tokens: OAuthToken)

## Called when token can't be refreshed cause auth was removed or refresh token expired
signal unauthenticated()

## Where to get the tokens from
@export var oauth_setting: OAuthSetting

## Holds the current set of tokens
@export var token: OAuthToken: set = _update_token

## Client to request new tokens
var _http_client : OAuthHTTPClient

## Is currently requesting tokens
var _requesting_token: bool = false

## Timer to refresh tokens
var _expiration_check_timer: Timer


func _ready() -> void:
	_http_client = OAuthHTTPClient.new()
	_http_client.name = "OAuthTokenClient"
	add_child(_http_client)
	
	_expiration_check_timer = Timer.new()
	_expiration_check_timer.name = "ExpirationCheck"
	_expiration_check_timer.timeout.connect(refresh_tokens)
	add_child(_expiration_check_timer)
	update_expiration_check()
	
	
func _enter_tree() -> void:
	if not is_instance_valid(token):
		token = OAuthToken.new()
	else:
		token.changed.connect(update_expiration_check)


func _exit_tree() -> void:
	if is_instance_valid(token):
		token.changed.disconnect(update_expiration_check)


func _update_token(val: OAuthToken) -> void:
	if is_instance_valid(token) and is_inside_tree():
		token.changed.disconnect(update_expiration_check)
	token = val
	if is_instance_valid(token) and is_inside_tree():
		token.changed.connect(update_expiration_check)


func update_expiration_check() -> void:
	var current_time: float = Time.get_unix_time_from_system()
	var expiration: int = token.get_expiration()
	if expiration == 0: 
		logDebug("Disable automate use of refresh token")
		_expiration_check_timer.stop()
		return
	_expiration_check_timer.start(expiration - current_time - SECONDS_TO_CHECK_EARLIER)
	logDebug("start timer to refresh token (%s) in %s seconds" % [token, roundf(_expiration_check_timer.wait_time)])


## Checks if tokens expires and starts refreshing it. (called often hold footprintt small)
func _check_token_refresh() -> void:
	if _requesting_token: return

	if token_needs_refresh():
		logInfo("Token (%s) needs refresh" % token)
		refresh_tokens()


## Requests the tokens
func request_token(grant_type: String, auth_code: String = ""):
	if _requesting_token: return
	_requesting_token = true
	logInfo("Request token (for %s) via '%s'" % [token, grant_type])
	var request_params: Array[String] = [
		"grant_type=%s" % grant_type,
		"client_id=%s" % oauth_setting.client_id,
		"client_secret=%s" % oauth_setting.get_client_secret()
	]

	if auth_code != "":
		request_params.append("code=%s" % auth_code)
	if grant_type == "authorization_code":
		request_params.append("&redirect_uri=%s" % oauth_setting.redirect_url)

	var request_body: String = "&".join(request_params)
	var request: BufferedHTTPClient.RequestData = _http_client.request(oauth_setting.token_url, \
		HTTPClient.METHOD_POST, HEADERS, request_body)
	await _handle_token_request(request)
	_requesting_token = false


func request_device_token(device_code_repsonse: OAuthDeviceCodeResponse, scopes: String, grant_type: String = "urn:ietf:params:oauth:grant-type:device_code") -> void:
	if _requesting_token: return
	_requesting_token = true
	logInfo("request token (for %s) via urn:ietf:params:oauth:grant-type:device_code" % token)
	var parameters: Array[String] = [
		"client_id=%s" % oauth_setting.client_id,
		"grant_type=%s" % grant_type,
		"device_code=%s" % device_code_repsonse.device_code,
		"scopes=%s" % scopes
	]

	var request_body: String = "&".join(parameters)

	# Time when the code is expired and we don't poll anymore
	var expire_data = Time.get_unix_time_from_system() + device_code_repsonse.expires_in

	while expire_data > Time.get_unix_time_from_system():
		var request: BufferedHTTPClient.RequestData = _http_client.request(oauth_setting.token_url, HTTPClient.METHOD_POST, HEADERS, request_body)
		var response = await _http_client.wait_for_request(request)
		var response_string: String = response.response_data.get_string_from_utf8()
		var response_data = JSON.parse_string(response_string)
		if response.response_code == 200:
			_update_tokens_from_response(response_data)
			_requesting_token = false
			return
		elif response.response_code == 400 && response_string.contains("authorization_pending"):
			# Awaits for this amount of time until retry
			await get_tree().create_timer(device_code_repsonse.interval, true, false, true).timeout
		elif response.response_code == 400:
			unauthenticated.emit()
			_requesting_token = false
			return

	# Handle Timeout
	unauthenticated.emit()
	_requesting_token = false


## Uses the refresh token if possible to refresh all tokens
func refresh_tokens() -> void:
	if not oauth_setting.is_valid(): 
		logError("Try to refresh token (%s) but oauth settings are invalid. Can't refresh token." % token)
		_expiration_check_timer.stop()
		return

	if _requesting_token: return
	_requesting_token = true
	logInfo("use refresh (%s) token" % token)
	if token.has_refresh_token():
		var request_body: String = "client_id=%s&client_secret=%s&refresh_token=%s&grant_type=refresh_token" % \
 			[oauth_setting.client_id, oauth_setting.get_client_secret(), token.get_refresh_token()]
		var request: BufferedHTTPClient.RequestData = _http_client.request(oauth_setting.token_url, \
			HTTPClient.METHOD_POST, HEADERS, request_body)
		if await _handle_token_request(request):
			logInfo("token (%s) got refreshed" % token)
		else:
			unauthenticated.emit()
	else:
		unauthenticated.emit()
	_requesting_token = false


## Gets information from the response and update values returns true when success otherwise false
func _handle_token_request(request: OAuthHTTPClient.RequestData) -> bool:
	var response = await _http_client.wait_for_request(request)
	var response_string = response.response_data.get_string_from_utf8()
	var result = JSON.parse_string(response_string)
	if response.response_code == 200:
		_update_tokens_from_response(result)
		return true
	else:
		# Reset expiration cause token wasn't refreshed correctly.
		token.invalidate()
	logError("token (for %s) could not be fetched ResponseCode %s / Body %s" % [token, response.response_code, response_string])
	return false


func _update_tokens_from_response(result: Dictionary):
	var scopes: Array[String] = []
	for scope in result.get("scope", []): scopes.append(scope)
	var type: StringName = &"" 
	if oauth_setting.authorization_flow == OAuth.AuthorizationFlow.CLIENT_CREDENTIALS:
		type = OAuthToken.APP_ACCESS_TOKEN
	else:
		type = OAuthToken.USER_ACCESS_TOKEN
		
	update_tokens(result["access_token"], \
		result.get("refresh_token", ""), \
		result.get("expires_in", -1), \
		scopes,
		type)


## Updates the token. Result is the response data of an token request.
func update_tokens(access_token: String, refresh_token: String = "", expires_in: int = -1, scopes: Array[String] = [], type: StringName = &""):
	token.update_values(access_token, refresh_token, expires_in, scopes, type)
	token_resolved.emit(token)
	logInfo("token (%s) resolved" % token)


func get_token_expiration() -> String:
	return Time.get_datetime_string_from_unix_time(token._expire_date)


## Checks if the token are valud
func is_token_valid() -> bool:
	return token.is_token_valid()


## Checks if the token is expired and can be refreshed
func token_needs_refresh() -> bool:
	return !token.is_token_valid() && token.has_refresh_token()


func get_access_token() -> String: return await token.get_access_token()


func has_refresh_token() -> bool: return token.has_refresh_token()


func get_scopes() -> PackedStringArray: return token.get_scopes()


# === LOGGER ===
static var logger: Dictionary = {}


static func set_logger(error: Callable, info: Callable, debug: Callable) -> void:
	logger.debug = debug
	logger.info = info
	logger.error = error


static func logDebug(text: String) -> void:
	if logger.has("debug"): logger.debug.call(text)


static func logInfo(text: String) -> void:
	if logger.has("info"): logger.info.call(text)


static func logError(text: String) -> void:
	if logger.has("error"): logger.error.call(text)
