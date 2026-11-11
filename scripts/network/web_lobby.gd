extends Node
## Browser peers exchange complete WebRTC offers/answers as portable invite codes.
## No signaling account is required. STUN discovers public routes; no TURN relay
## is configured, so restrictive networks may be unable to connect directly.
signal code_ready(code: String)
signal status_changed(message: String)
signal player_linked
const PREFIX := "HNS1."
const MAX_CODE := 32768
var code := ""
var status := ""
var hosting := false
var peer: WebRTCMultiplayerPeer
var _connection: WebRTCPeerConnection
var _connections: Dictionary = {}
var _id := 0
var _nonce := ""
var _description := ""
var _candidates: Array = []
var _remote_candidates: Array = []
var _deadline := 0
var _code_sent := false
var _answered := false
var _generation := 0
var _gather_started := 0
var _last_candidate := 0

func _ready() -> void:
 multiplayer.peer_connected.connect(_on_peer_connected)

func host() -> Error:
 close()
 hosting = true
 peer = WebRTCMultiplayerPeer.new()
 var error := peer.create_server()
 if error != OK: return error
 multiplayer.multiplayer_peer = peer
 return create_invite()

func create_invite() -> Error:
 if not hosting or not peer: return ERR_UNAVAILABLE
 if _connection and _connection.get_connection_state() != WebRTCPeerConnection.STATE_CONNECTED:
  peer.remove_peer(_id)
  _connection.close()
  _connections.erase(_id)
 _generation += 1
 _id = randi_range(2, 2147483646)
 while peer.has_peer(_id): _id = randi_range(2, 2147483646)
 _nonce = Crypto.new().generate_random_bytes(16).hex_encode()
 _reset_exchange()
 var error := _new_connection(_id)
 if error != OK: return error
 _set_status("Preparing your invite…")
 return _connection.create_offer()

func join_invite(invite: String) -> Error:
 var data := decode_code(invite, "offer")
 if data.is_empty():
  _set_status("Paste a complete host invite code beginning with HNS1.")
  return ERR_INVALID_DATA
 close()
 hosting = false
 _id = int(data.peer)
 _nonce = data.nonce
 _reset_exchange()
 peer = WebRTCMultiplayerPeer.new()
 var error := peer.create_client(_id)
 if error != OK: return error
 multiplayer.multiplayer_peer = peer
 error = _new_connection(1)
 if error != OK: return error
 _remote_candidates = data.ice
 _set_status("Preparing your reply…")
 return _connection.set_remote_description("offer", data.sdp)

func accept_reply(reply: String) -> Error:
 var data := decode_code(reply, "answer")
 if not hosting or _answered or not _connection or data.is_empty() or int(data.peer) != _id or data.nonce != _nonce:
  _set_status("That reply does not match this invite. Ask your friend for its reply code.")
  return ERR_INVALID_DATA
 _answered = true
 _remote_candidates = data.ice
 _set_status("Connecting to your friend…")
 _deadline = Time.get_ticks_msec() + 30000
 return _connection.set_remote_description("answer", data.sdp)

func _new_connection(remote_id: int) -> Error:
 _connection = WebRTCPeerConnection.new()
 var error := _connection.initialize({"iceServers": [{"urls": ["stun:stun.l.google.com:19302", "stun:stun.cloudflare.com:3478"]}]})
 if error != OK: return error
 _connections[remote_id] = _connection
 var generation := _generation
 _connection.session_description_created.connect(func(type: String, sdp: String):
  if generation == _generation: _on_description(type, sdp))
 _connection.ice_candidate_created.connect(func(media: String, index: int, candidate: String):
  if generation == _generation:
   _candidates.append({"m": media, "i": index, "c": candidate})
   _last_candidate = Time.get_ticks_msec())
 return peer.add_peer(_connection, remote_id)

func _reset_exchange() -> void:
 code = ""
 _gather_started = Time.get_ticks_msec()
 _last_candidate = _gather_started
 _description = ""
 _candidates = []
 _remote_candidates = []
 _code_sent = false
 _answered = false
 _deadline = Time.get_ticks_msec() + 300000

func _on_description(type: String, sdp: String) -> void:
 _description = sdp
 var error := _connection.set_local_description(type, sdp)
 if error != OK: _set_status("Your browser could not prepare a connection. Try a fresh invite.")

func _process(_delta: float) -> void:
 if not _connection: return
 if not _remote_candidates.is_empty() and _connection.get_signaling_state() == WebRTCPeerConnection.SIGNALING_STATE_STABLE:
  for candidate in _remote_candidates: _connection.add_ice_candidate(candidate.m, int(candidate.i), candidate.c)
  _remote_candidates = []
 var gathered := _connection.get_gathering_state() == WebRTCPeerConnection.GATHERING_STATE_COMPLETE
 # An unreachable STUN server can delay the browser's gathering-complete event.
 # Publish already-discovered routes after a quiet period instead of hanging UI.
 gathered = gathered or (not _candidates.is_empty() and Time.get_ticks_msec() - _gather_started > 5000 and Time.get_ticks_msec() - _last_candidate > 1000)
 if not _code_sent and not _description.is_empty() and gathered:
  _code_sent = true
  code = encode_code({"v": 1, "kind": "offer" if hosting else "answer", "peer": _id, "nonce": _nonce, "sdp": _description, "ice": _candidates})
  _set_status("Send this invite to one friend, then paste their reply below." if hosting else "Send this reply to the host. Keep this page open while they connect.")
  code_ready.emit(code)
 var state := _connection.get_connection_state()
 if state == WebRTCPeerConnection.STATE_FAILED:
  _set_status("Direct connection failed. Try a fresh invite or another network; some networks require a relay.")
  _deadline = 0
 elif _deadline > 0 and Time.get_ticks_msec() > _deadline and state != WebRTCPeerConnection.STATE_CONNECTED:
  _set_status("Invite timed out. Create a fresh invite and exchange both codes again.")
  _deadline = 0

func _on_peer_connected(id: int) -> void:
 if (hosting and id == _id) or (not hosting and id == 1):
  _deadline = 0
  _set_status("Connected!")
  player_linked.emit()

func _set_status(message: String) -> void:
 status = message
 status_changed.emit(message)

func close() -> void:
 _generation += 1
 for connection in _connections.values(): connection.close()
 _connections.clear()
 _connection = null
 if peer: peer.close()
 peer = null
 code = ""
 _deadline = 0
 hosting = false

static func encode_code(data: Dictionary) -> String:
 return PREFIX + Marshalls.raw_to_base64(JSON.stringify(data).to_utf8_buffer().compress(FileAccess.COMPRESSION_DEFLATE))

static func decode_code(value: String, kind: String) -> Dictionary:
 if value.length() > MAX_CODE * 2: return {}
 value = value.strip_edges().replace("\n", "").replace("\r", "").replace(" ", "")
 if not value.begins_with(PREFIX) or value.length() > MAX_CODE: return {}
 var compressed := Marshalls.base64_to_raw(value.trim_prefix(PREFIX))
 if compressed.is_empty(): return {}
 var bytes := compressed.decompress_dynamic(65536, FileAccess.COMPRESSION_DEFLATE)
 if bytes.is_empty(): return {}
 var data: Variant = JSON.parse_string(bytes.get_string_from_utf8())
 if not data is Dictionary: return {}
 if data.get("v") != 1 or data.get("kind") != kind: return {}
 if not data.get("peer") is float and not data.get("peer") is int: return {}
 if int(data.peer) < 2 or int(data.peer) > 2147483647: return {}
 if not data.get("nonce") is String or data.nonce.length() != 32: return {}
 if not data.get("sdp") is String or not data.sdp.begins_with("v=0") or data.sdp.length() > 24000: return {}
 if not data.get("ice") is Array or data.ice.size() > 64: return {}
 for candidate in data.ice:
  if not candidate is Dictionary: return {}
  if not candidate.get("m") is String or candidate.m.length() > 64: return {}
  if not candidate.get("c") is String or candidate.c.length() > 2048: return {}
  if not candidate.get("i") is int and not candidate.get("i") is float: return {}
  if int(candidate.i) < 0 or int(candidate.i) > 31: return {}
 return data
