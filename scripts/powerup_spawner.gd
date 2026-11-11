extends Node3D
class_name PowerUpSpawner

signal powerup_spawned(powerup_type: int, position: Vector3)

@export var spawn_interval: float = 15.0 as float
@export var max_active_powerups: int = 10

var last_spawn_time: float = 0.0
var active_powerups: Array[Node3D] = []

func _process(delta):
	var now = Time.get_ticks_msec() / 1000.0
	
	if now - last_spawn_time >= spawn_interval and active_powerups.size() < max_active_powerups:
		last_spawn_time = now
		spawn_random_powerup()

func spawn_random_powerup():
	# Random position within arena bounds (-40 to 40 on x/z)
	var position = Vector3(
		(randf_range(-40.0, 40.0)),
		2.5,
		(randf_range(-40.0, 40.0))
	)
	
	# Random powerup type (0=camouflage, 1=speed boost, 2=invisibility, 3=flashbang)
	var powerup_type = randi() % 4
	
	# Create visual indicator for the powerup
	var powerup_node := PackedScene.new().instance() as Node3D
	if not powerup_node: return
	
	powerup_node.position = position
	powerup_node.name = "PowerUp_%d" % Time.get_ticks_msec()
	
	# Visual representation (simple glowing sphere)
	var mesh := SphereMesh.new()
	mesh.radius = 0.8
	var material := StandardMaterial3D.new()
	material.shading_mode = StandardMaterial3D.SHADING_MODE_UNLIT
	
	match powerup_type:
		0: # CAMOUFLAGE - Grayish color
			material.albedo_color = Color(0.3, 0.3, 0.4)
		1: # SPEED_BOOST - Orange/Yellow
			material.albedo_color = Color(1.0, 0.8, 0.2)
		2: # INVISIBILITY - Purple
			material.albedo_color = Color(0.5, 0.3, 0.9)
		3: # FLASHBANG - Red/Orange flash
			material.albedo_color = Color(1.0, 0.4, 0.2)
	
	powerup_node.add_child(mesh)
	powerup_node.add_child(material)
	
	active_powerups.append(powerup_node)
	powerup_spawned.emit(powerup_type, position)

func cleanup_old_powerups():
	var now = Time.get_ticks_msec() / 1000.0
	
	for powerup in active_powerups:
		if now - powerup.created_time > 30.0:  # Remove after 30 seconds
			powerup.queue_free()

func get_active_count():
	return active_powerups.size()

EOF