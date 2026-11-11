extends Node
var failures:=0
func check(condition:bool,message:String) -> void:
 if not condition:push_error(message);failures+=1
func _ready() -> void:call_deferred("run")
func run() -> void:
 var loaded=load("res://scenes/level/level.tscn").instantiate()
 get_tree().root.add_child(loaded)
 get_tree().current_scene=loaded
 await get_tree().process_frame
 await get_tree().process_frame
 var scene=get_tree().current_scene
 var player=load("res://scenes/level/player.tscn").instantiate()
 player.name="1";scene.players_container.add_child(player)
 Network.players[1]={"nick":"Tester","skin":0}
 await get_tree().create_timer(1).timeout
 check(Shooter.actors.has(1),"Host actor registered")
 check(Shooter.actors.size()==4,"Three practice bots registered")
 check(player.player_inventory.get_slot(0).item_id=="pistol","Starter pistol shares actual inventory")
 check(Shooter.selected_gun(1)=="pistol","Hotbar selects inventory weapon")
 Shooter.phase="active"
 var a:Dictionary=Shooter.actors[1];a.shield=0
 Shooter.damage(1,20,-1)
 check(a.hp==80,"Enemy hit changes server health")
 var before:float=a.hp
 Shooter.damage(1,20,-2)
 check(a.hp==before,"Friendly fire blocked")
 check(Shooter.give_gun(1,"rifle"),"Can collect rifle")
 check(player.player_inventory.get_slot(1).item_id=="rifle","Rifle stored in template inventory")
 Shooter.give_gun(1,"rifle")
 check(player.player_inventory.get_slot(2).is_empty(),"Duplicate rifle adds ammo instead of item")
 Shooter.select_slot(1)
 check(Shooter.selected_gun(1)=="rifle","Hotbar switching works")
 a.guns.rifle.mag=0
 Shooter.reload_gun()
 check(a.reload>Shooter.now(),"Reload starts")
 a.reload=Shooter.now()-0.01
 Shooter.server_tick(0.01)
 check(a.guns.rifle.mag==24,"Reload fills magazine")
 check(a.guns.rifle.reserve<120,"Reload consumes reserves")
 # Real physics-ray shooting, ammunition and fire-rate validation.
 Shooter.select_slot(0)
 player.global_position=Vector3(0,1,0)
 var target=Shooter.actor_node(-1)
 target.global_position=Vector3(0,1,-8)
 player.set_physics_process(false)
 target.set_physics_process(false)
 Shooter.set_process(false)
 await get_tree().physics_frame
 await get_tree().physics_frame
 Shooter.actors[-1].hp=100;Shooter.actors[-1].shield=0
 a.last_shot=0;a.reload=0;a.sprint=false
 var ammo_before:int=a.guns.pistol.mag
 Shooter.shoot(1,player.global_position+Vector3.UP*1.5,Vector3.FORWARD)
 check(a.guns.pistol.mag==ammo_before-1,"Actual shot consumes one round")
 check(Shooter.actors[-1].hp==80,"Actual ray hit damages enemy")
 Shooter.shoot(1,player.global_position+Vector3.UP*1.5,Vector3.FORWARD)
 check(a.guns.pistol.mag==ammo_before-1,"Fire rate rejects repeated immediate shots")
 a.last_shot=0
 Shooter.shoot(1,Vector3(10000,10000,10000),Vector3.FORWARD)
 check(a.guns.pistol.mag==ammo_before-1,"Forged origin cannot fire")
 a.guns.pistol.mag=0
 Shooter.shoot(1,player.global_position+Vector3.UP*1.5,Vector3.FORWARD)
 check(Shooter.actors[-1].hp==80,"Empty magazine cannot damage")
 # Inventory moves and drops must retain the same weapon-instance ammunition.
 a.guns.rifle.mag=7
 check(player.player_inventory.swap_items(0,1),"Can rearrange hotbar inventory")
 check(player.player_inventory.get_slot(0).weapon_state.mag==7,"Weapon ammo follows inventory swap")
 Shooter.drop_gun(1,"rifle")
 check(not a.guns.has("rifle"),"Dropped weapon removed from combat state")
 check(Shooter.pickups.back().ammo.mag==7,"Dropped weapon retains its partial magazine")
 check(Shooter.give_gun(1,"rifle",7,20),"Can recover weapon")
 Shooter.team_scores=[30,0];Shooter.check_winner()
 check(Shooter.phase=="results" and Shooter.result.contains("Blue"),"Team score ends match")
 Shooter.mode=1;Shooter.phase="active";a.score=15;Shooter.check_winner()
 check(Shooter.phase=="results","FFA score ends match")
 Shooter.mode=2;Shooter.phase="active";Shooter.elapsed=100
 for id in Shooter.actors:Shooter.actors[id].hp=0
 a.hp=100;Shooter.check_winner()
 check(Shooter.result.contains("last player"),"Survival last living actor wins")
 check(Network.sanitize_address("wss://game.example.com")=="wss://game.example.com","Browser secure WebSocket address accepted")
 check(Network.sanitize_address("wss://evil/path")=="","Unexpected socket path rejected")
 print("SHOOTER_TEST failures=",failures)
 get_tree().quit(failures)
