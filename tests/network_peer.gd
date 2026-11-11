extends Node
var failed:=false
func check(ok:bool,message:String) -> void:
 if not ok:push_error(message);failed=true
func _ready() -> void:call_deferred("run")
func run() -> void:
 var server:bool="--net-server" in OS.get_cmdline_user_args()
 Network.practice_bots=0
 var scene=load("res://scenes/level/level.tscn").instantiate()
 get_tree().root.add_child(scene);get_tree().current_scene=scene
 if server:
  await get_tree().create_timer(12).timeout
  check(Network.players.size()==2,"Dedicated server sees both connected clients")
  check(Shooter.actors.size()==2,"Server has exactly the two human actors")
  print("NETWORK_SERVER peers=",Network.players.size()," actors=",Shooter.actors.size()," failed=",failed)
 else:
  await get_tree().create_timer(4).timeout
  var id:=multiplayer.get_unique_id()
  check(Shooter.actors.has(id),"Client receives own combat state")
  check(Shooter.actors.size()==2,"Client sees both actors")
  if not Shooter.actors.has(id):get_tree().quit(1);return
  var player=Shooter.human(id)
  check(player!=null,"Client has its replicated player node")
  Shooter.request_fire.rpc_id(1,Vector3(10000,0,0),Vector3.FORWARD)
  await get_tree().create_timer(0.3).timeout
  check(Shooter.actors[id].guns.pistol.mag==12,"Forged remote shot rejected")
  Shooter.request_fire.rpc_id(1,player.global_position+Vector3.UP*1.5,Vector3.RIGHT)
  await get_tree().create_timer(0.3).timeout
  check(Shooter.actors[id].guns.pistol.mag==11,"Valid remote shot consumes one authoritative round")
  Shooter.reload_gun.rpc_id(1)
  await get_tree().create_timer(1.6).timeout
  check(Shooter.actors[id].guns.pistol.mag==12,"Reload state returns to client")
  check(Shooter.actors[id].guns.pistol.reserve==35,"Reload reserve decremented on server")
  print("NETWORK_CLIENT id=",id," actors=",Shooter.actors.size()," failed=",failed)
  await get_tree().create_timer(7).timeout
 get_tree().quit(1 if failed else 0)
