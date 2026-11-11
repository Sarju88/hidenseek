# Remove fog effect when inactive
func _remove_fog_effect():
	for mesh in [_bottom_mesh, _chest_mesh, _face_mesh, _limbs_head_mesh]:
		if mesh:
			var material = mesh.get_surface_material(0) as StandardMaterial3D
			if material and material.shading_mode == StandardMaterial3D.SHADING_MODE_UNLIT:
				material.shading_mode = StandardMaterial3D.SHADING_MODE_STANDARD


# Power-up Effect Handling for Hiders
func apply_powerup_effect(powerup_type: int):
	match powerup_type:
		0: # CAMOUFLAGE - Change to environment color (grayish)
			for mesh in [_bottom_mesh, _chest_mesh, _face_mesh, _limbs_head_mesh]:
				if mesh and mesh.get_surface_material(0) is StandardMaterial3D:
					var mat = mesh.get_surface_material(0) as StandardMaterial3D
					mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNLIT
					mat.albedo_color = Color(0.3, 0.3, 0.4)
		1: # SPEED_BOOST - Already handled by _move() via flag check
			pass
		2: # INVISIBILITY - Similar to fog but stronger
			for mesh in [_bottom_mesh, _chest_mesh, _face_mesh, _limbs_head_mesh]:
				if mesh and mesh.get_surface_material(0) is StandardMaterial3D:
					var mat = mesh.get_surface_material(0) as StandardMaterial3D
					mat.shading_mode = StandardMaterial3D.SHADING_MODE_UNLIT
					mat.albedo_color = Color(0.1, 0.1, 0.2)
		3: # FLASHBANG - Visual flash effect handled by powerup system
			pass

func remove_powerup_effect(powerup_type: int):
	match powerup_type:
		0: # CAMOUFLAGE - Restore original texture
			for mesh in [_bottom_mesh, _chest_mesh, _face_mesh, _limbs_head_mesh]:
				if mesh and mesh.get_surface_material(0) is StandardMaterial3D:
					var mat = mesh.get_surface_material(0) as StandardMaterial3D
					mat.shading_mode = StandardMaterial3D.SHADING_MODE_STANDARD
		2: # INVISIBILITY - Restore original texture
			for mesh in [_bottom_mesh, _chest_mesh, _face_mesh, _limbs_head_mesh]:
				if mesh and mesh.get_surface_material(0) is StandardMaterial3D:
					var mat = mesh.get_surface_material(0) as StandardMaterial3D
					mat.shading_mode = StandardMaterial3D.SHADING_MODE_STANDARD


# Apply fog effect to player meshes when active
func _apply_fog_effect():
	for mesh in [_bottom_mesh, _chest_mesh, _face_mesh, _limbs_head_mesh]:
		if mesh:
			var material = mesh.get_surface_material(0) as StandardMaterial3D
			if material:
				material.shading_mode = StandardMaterial3D.SHADING_MODE_UNLIT
				material.albedo_color = fog_color * fog_intensity


# Remove fog effect when inactive
func _remove_fog_effect():
	for mesh in [_bottom_mesh, _chest_mesh, _face_mesh, _limbs_head_mesh]:
		if mesh:
			var material = mesh.get_surface_material(0) as StandardMaterial3D
			if material and material.shading_mode == StandardMaterial3D.SHADING_MODE_UNLIT:
				material.shading_mode = StandardMaterial3D.SHADING_MODE_STANDARD
