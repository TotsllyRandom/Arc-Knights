extends Area3D

@export var speed: float = 30.0

var direction := Vector3.FORWARD
var damage := 10
var knockback_scale := 1.0
var max_range := 30.0
var distance_travelled := 0.0


# Called by the player right after the bullet is added to the scene.
# "weapon" is one of the dictionaries in weapons.gd, and "color" is the color of the player's light.
func launch(origin: Vector3, aim: Vector3, weapon: Dictionary, color: Color = Color(1.0, 0.0, 0.0)) -> void:
	global_position = origin
	direction = aim.normalized()
	speed = weapon.get("bullet_speed", speed)
	damage = weapon.get("damage", damage)
	knockback_scale = weapon.get("knockback_scale", 1.0)
	max_range = weapon.get("range", max_range)
	apply_color(color)
	# look_at doesn't work when the direction is straight up or down
	if direction.cross(Vector3.UP).length() > 0.001:
		look_at(origin + direction, Vector3.UP)


# Tints the bullet and its glow. Bullets are red unless the player's light is another color.
func apply_color(color: Color) -> void:
	var mesh_instance := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh_instance == null:
		return

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 3.0
	material.disable_receive_shadows = true
	mesh_instance.material_override = material

	var glow := mesh_instance.get_node_or_null("OmniLight3D") as OmniLight3D
	if glow != null:
		glow.light_color = color


# Moving in _process (instead of _physics_process) keeps the bullet smooth at any frame rate
func _process(delta: float) -> void:
	var step := speed * delta
	global_position += direction * step
	distance_travelled += step
	if distance_travelled >= max_range:
		queue_free()


func _on_body_entered(body: Node) -> void:
	# Never hit the player who fired it
	if body.is_in_group("player"):
		return
	if body.has_method("take_damage"):
		body.take_damage(damage, direction, knockback_scale)
	queue_free() # Destroy bullet on impact
