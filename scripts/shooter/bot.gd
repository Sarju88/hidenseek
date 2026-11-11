extends CharacterBody3D
var target:=Vector3.ZERO
func _physics_process(delta:float) -> void:
 if not multiplayer.has_multiplayer_peer() or not multiplayer.is_server():return
 var id:int=get_meta("combat_id",0)
 if not Shooter.actors.has(id) or Shooter.actors[id].hp<=0 or Shooter.phase in ["countdown","results"]:return
 var agent:NavigationAgent3D=get_node_or_null("NavigationAgent3D")
 if not agent:return
 if NavigationServer3D.map_get_iteration_id(agent.get_navigation_map())==0:return
 agent.target_position=target
 var direction:Vector3=agent.get_next_path_position()-global_position;direction.y=0
 velocity.x=direction.normalized().x*4;velocity.z=direction.normalized().z*4
 if not is_on_floor():velocity.y-=18*delta
 if direction.length()>0.1:rotation.y=atan2(-direction.x,-direction.z)
 move_and_slide()
