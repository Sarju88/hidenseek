class_name CloudflarePeer
extends MultiplayerPeerExtension
## Godot RPC packets over a Cloudflare room. All delivery is ordered/reliable.
signal relay_ready
signal relay_error(message: String)
var socket := WebSocketPeer.new()
var status := MultiplayerPeer.CONNECTION_DISCONNECTED
var unique_id := 0
var hosting := false
var target := 0
var channel := 0
var mode := MultiplayerPeer.TRANSFER_MODE_RELIABLE
var refusing := false
var packets: Array[PackedByteArray] = []
var peers: Dictionary = {}

func connect_room(url: String, host_room: bool) -> Error:
 hosting = host_room
 socket.inbound_buffer_size = 4194304
 socket.outbound_buffer_size = 4194304
 socket.max_queued_packets = 4096
 var error := socket.connect_to_url(url + ("?host=1" if hosting else "?host=0"))
 if error == OK: status = MultiplayerPeer.CONNECTION_CONNECTING
 return error

func _poll() -> void:
 socket.poll()
 if socket.get_ready_state() == WebSocketPeer.STATE_CLOSED:
  if status != MultiplayerPeer.CONNECTION_DISCONNECTED:
   relay_error.emit(socket.get_close_reason() if not socket.get_close_reason().is_empty() else "Room unavailable. Host first, or check the room code.")
  status = MultiplayerPeer.CONNECTION_DISCONNECTED
  return
 while socket.get_available_packet_count() > 0:
  var data := socket.get_packet()
  if socket.was_string_packet():
   var message = JSON.parse_string(data.get_string_from_utf8())
   if not message is Dictionary: continue
   match str(message.get("type", "")):
    "welcome":
     unique_id = int(message.id)
     status = MultiplayerPeer.CONNECTION_CONNECTED
     relay_ready.emit()
     for id in message.peers: _add_peer(int(id))
    "joined": _add_peer(int(message.id))
    "left":
     var id := int(message.id)
     if peers.has(id):
      peers.erase(id)
      peer_disconnected.emit(id)
  elif data.size() >= 12:
   if packets.size() >= 4096:
    _close()
    return
   packets.append(data)

func _add_peer(id: int) -> void:
 if id != unique_id and not peers.has(id):
  peers[id] = true
  peer_connected.emit(id)

func _put_packet_script(buffer: PackedByteArray) -> Error:
 if status != MultiplayerPeer.CONNECTION_CONNECTED: return ERR_UNCONFIGURED
 if buffer.size() > 65524: return ERR_INVALID_PARAMETER
 var data := PackedByteArray()
 data.resize(12)
 data.encode_s32(0, target)
 data.encode_u32(4, channel)
 data.encode_u32(8, mode)
 data.append_array(buffer)
 return socket.send(data)

func _get_packet_script() -> PackedByteArray:
 if packets.is_empty(): return PackedByteArray()
 return packets.pop_front().slice(12)
func _get_available_packet_count() -> int: return packets.size()
func _get_packet_peer() -> int: return packets[0].decode_s32(0) if not packets.is_empty() else 0
func _get_packet_channel() -> int: return packets[0].decode_u32(4) if not packets.is_empty() else 0
func _get_packet_mode() -> MultiplayerPeer.TransferMode: return packets[0].decode_u32(8) as MultiplayerPeer.TransferMode if not packets.is_empty() else MultiplayerPeer.TRANSFER_MODE_RELIABLE
func _get_max_packet_size() -> int: return 65524
func _get_unique_id() -> int: return unique_id
func _get_connection_status() -> MultiplayerPeer.ConnectionStatus: return status
func _is_server() -> bool: return hosting
func _is_server_relay_supported() -> bool: return false
func _set_target_peer(value: int) -> void: target = value
func _set_transfer_channel(value: int) -> void: channel = value
func _get_transfer_channel() -> int: return channel
func _set_transfer_mode(value: MultiplayerPeer.TransferMode) -> void: mode = value
func _get_transfer_mode() -> MultiplayerPeer.TransferMode: return mode
func _is_refusing_new_connections() -> bool: return refusing
func _set_refuse_new_connections(value: bool) -> void:
 refusing = value
 if hosting and status == MultiplayerPeer.CONNECTION_CONNECTED: socket.send_text(JSON.stringify({"type":"refuse", "value":value}))
func _disconnect_peer(id: int, _force: bool) -> void:
 if hosting: socket.send_text(JSON.stringify({"type":"kick", "id":id}))
 elif id == 1: _close()
func _close() -> void:
 socket.close()
 status = MultiplayerPeer.CONNECTION_DISCONNECTED
 packets.clear()
 peers.clear()
