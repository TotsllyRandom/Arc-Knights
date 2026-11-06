extends CharacterBody3D

const Weapons = preload("res://Scripts/weapons.gd")

var gun_cd := 0.0:
	set(new):
		if new <= 0:
			gun_cd = 0.0
		else:
			gun_cd = new

@onready var cam_rotate = $RotateCamera
var bullet = preload("res://Scenes/bullet.tscn")

const SPEED = 5.0
const JUMP_VELOCITY = 4.5
var target_rotation : Vector3

# Height above the player's feet that shots come from, and how far in front of the player they start
const GUN_HEIGHT := 1.0
const MUZZLE_DISTANCE := 0.8
# A click this close before the weapon is ready still fires as soon as it is
const FIRE_BUFFER_TIME := 0.15
# Short pause after swapping so a swap can't also fire instantly
const WEAPON_SWITCH_DELAY := 0.2
# Pause between "click" attempts when the gun is empty
const DRY_FIRE_DELAY := 0.2
# How long a melee lunge takes
const LUNGE_TIME := 0.12

var weapon_index := 0
var weapon: Dictionary = {}
var fire_buffer := 0.0
var mouse_was_down := false
var burst_shots_left := 0
var burst_timer := 0.0

# Ammo: loaded bullets (a fraction means a bullet is partly reloaded)
var ammo := 0.0
# Reloading is paused until this runs out, and it's refilled every time a shot is fired
var reload_pause := 0.0
# Each weapon keeps its own loaded ammo while it's put away
var ammo_by_weapon := {}
# The color of the player's light. Bullets and the ammo icon use it; it's red until a light sets it.
var light_color := Color(1.0, 0.0, 0.0)

# Ammo counter (bottom right): an animated bullet icon, the number of loaded bullets next to it,
# and a bar that fills upward while reloading. The max ammo only shows while hovering over it.
const BULLET_ICON := preload("res://assets/Bullet Info.png")
const ICON_FRAME_SIZE := 16
const ICON_FRAME_TIME := 0.12
const ICON_DISPLAY_SIZE := 48

var ammo_box: HBoxContainer
var ammo_icon: TextureRect
var ammo_icon_texture: AtlasTexture
var ammo_icon_material: ShaderMaterial
var ammo_number: Label
var reload_bar: ProgressBar
var reload_bar_fill: StyleBoxFlat
var ammo_hovered := false
var icon_frame := 0
var icon_timer := 0.0

# Melee
var melee_pending := false
var melee_windup_left := 0.0
var melee_aim := Vector3.FORWARD
var lunge_velocity := Vector3.ZERO
var lunge_time_left := 0.0


func check_camera_controls():
	if Input.is_action_just_pressed("Player_Camera_Left"):
		target_rotation.y -= PI/4
	if Input.is_action_just_pressed("Player_Camera_Right"):
		target_rotation.y += PI/4
	if Input.is_action_just_pressed("Player_Camera_Up"):
		target_rotation.x -= PI/8
	if Input.is_action_just_pressed("Player_Camera_Down"):
		target_rotation.x += PI/8
	target_rotation.x = clamp(target_rotation.x, -PI/2,-PI/4)
	

func _ready() -> void:
	add_to_group("player")
	_ensure_weapon_input()
	create_ammo_label()
	rotation.y = 0
	target_rotation.y = rotation.y
	target_rotation.x = cam_rotate.rotation.x
	equip_weapon(0)

func _physics_process(delta: float) -> void:
	if position.y <= -5:
		position.y = 5
	gun_cd -= delta
	check_camera_controls()
	rotation.y = lerp_angle(rotation.y,target_rotation.y, .3)
	cam_rotate.rotation.x = lerp_angle(cam_rotate.rotation.x,target_rotation.x, .3)
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("Player_Jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("Player_Move_Left", "Player_Move_Right", "Player_Move_Up", "Player_Move_Down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()

	# Melee lunge: a short step forward that still stops at walls
	if lunge_time_left > 0.0:
		lunge_time_left -= delta
		move_and_collide(lunge_velocity * delta)

	handle_weapon(delta)


# ---------------------------------------------------------------- weapons

# Makes sure the swap control exists. It's also in the project's Input Map as
# "Player_Swap_Weapon"; this just covers the case where it isn't there.
func _ensure_weapon_input() -> void:
	if not InputMap.has_action("Player_Swap_Weapon"):
		InputMap.add_action("Player_Swap_Weapon")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_L
		InputMap.action_add_event("Player_Swap_Weapon", key)


func is_gun() -> bool:
	return weapon.get("type", Weapons.Type.GUN) == Weapons.Type.GUN


# Switches to the next weapon in the list (wraps around)
func swap_weapon() -> void:
	equip_weapon(weapon_index + 1)


# Equips a weapon by its index in Weapons.LIST and updates the on-screen label.
# Later, the weapon type will be set from the character's gear by calling this.
func equip_weapon(index: int) -> void:
	# Put the old weapon's ammo away with it
	if not weapon.is_empty() and is_gun():
		ammo_by_weapon[weapon_index] = ammo

	weapon_index = wrapi(index, 0, Weapons.LIST.size())
	weapon = Weapons.LIST[weapon_index]
	ammo = ammo_by_weapon.get(weapon_index, float(weapon.get("max_ammo", 0)))
	reload_pause = 0.0

	# Cancel anything in progress from the old weapon
	burst_shots_left = 0
	melee_pending = false
	fire_buffer = 0.0
	gun_cd = WEAPON_SWITCH_DELAY
	update_weapon_label()
	update_ammo_label()


# The label that used to say "End Run" now shows the current weapon
func update_weapon_label() -> void:
	var label = get_node_or_null("../InteractText/Label")
	if label != null:
		label.text = weapon.get("name", "")


# Changes the color of the player's light, which recolors bullets and the ammo icon.
# Later this will be called with the color of the light the character is using.
func set_light_color(color: Color) -> void:
	light_color = color
	if ammo_icon_material != null:
		ammo_icon_material.set_shader_parameter("light_color", color)
	if reload_bar_fill != null:
		reload_bar_fill.bg_color = color


# Builds the ammo counter in the bottom right corner: [reload bar] [bullet icon] [number]
func create_ammo_label() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	ammo_box = HBoxContainer.new()
	layer.add_child(ammo_box)
	ammo_box.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ammo_box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ammo_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ammo_box.offset_right = -24.0
	ammo_box.offset_bottom = -24.0
	ammo_box.add_theme_constant_override("separation", 10)
	# The whole counter is the hover area
	ammo_box.mouse_filter = Control.MOUSE_FILTER_STOP
	ammo_box.mouse_entered.connect(func(): ammo_hovered = true)
	ammo_box.mouse_exited.connect(func(): ammo_hovered = false)

	# Reload bar, in the same plain style as the loading screen but standing up and filling from the bottom
	reload_bar = ProgressBar.new()
	reload_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	reload_bar.show_percentage = false
	reload_bar.min_value = 0.0
	reload_bar.max_value = 1.0
	reload_bar.custom_minimum_size = Vector2(12, ICON_DISPLAY_SIZE)
	reload_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	reload_bar_fill = StyleBoxFlat.new()
	reload_bar_fill.bg_color = light_color
	reload_bar.add_theme_stylebox_override("fill", reload_bar_fill)
	var bar_background := StyleBoxFlat.new()
	bar_background.bg_color = Color(0.0, 0.0, 0.0, 0.5)
	reload_bar.add_theme_stylebox_override("background", bar_background)
	reload_bar.modulate.a = 0.0
	ammo_box.add_child(reload_bar)

	# Bullet icon: one 16x16 frame of the 2x2 sprite sheet at a time, cycled in _process
	ammo_icon_texture = AtlasTexture.new()
	ammo_icon_texture.atlas = BULLET_ICON
	ammo_icon_texture.region = Rect2(0, 0, ICON_FRAME_SIZE, ICON_FRAME_SIZE)
	ammo_icon = TextureRect.new()
	ammo_icon.rotation = randi_range(0,4) * 90
	ammo_icon.texture = ammo_icon_texture
	ammo_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ammo_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ammo_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ammo_icon.custom_minimum_size = Vector2(ICON_DISPLAY_SIZE, ICON_DISPLAY_SIZE)
	ammo_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE

	# The sprite is red and white. This keeps the white and swaps the red for the light's color.
	var shader := Shader.new()
	shader.code = """
shader_type canvas_item;
uniform vec4 light_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	COLOR = vec4(mix(light_color.rgb, vec3(1.0), tex.g), tex.a);
}
"""
	ammo_icon_material = ShaderMaterial.new()
	ammo_icon_material.shader = shader
	ammo_icon_material.set_shader_parameter("light_color", light_color)
	ammo_icon.material = ammo_icon_material
	ammo_box.add_child(ammo_icon)

	# The number of loaded bullets, right next to the icon
	ammo_number = Label.new()
	ammo_number.custom_minimum_size = Vector2(96, ICON_DISPLAY_SIZE)
	ammo_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ammo_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ammo_number.add_theme_font_size_override("font_size", 32)
	ammo_box.add_child(ammo_number)


# Animates the bullet icon by stepping through the sheet's four frames
func _process(delta: float) -> void:
	icon_timer += delta
	if icon_timer >= ICON_FRAME_TIME:
		icon_timer = 0.0
		icon_frame = (icon_frame + 1) % 4
		if ammo_icon_texture != null:
			ammo_icon_texture.region = Rect2(
				(icon_frame % 2) * ICON_FRAME_SIZE,
				floori(icon_frame / 2.0) * ICON_FRAME_SIZE,
				ICON_FRAME_SIZE,
				ICON_FRAME_SIZE
			)


func update_ammo_label() -> void:
	if ammo_number == null:
		return

	# Melee weapons use no ammo, so there's no icon or bar
	ammo_icon.visible = is_gun()
	if not is_gun():
		ammo_number.text = "MELEE"
		ammo_number.add_theme_color_override("font_color", Color.WHITE)
		reload_bar.modulate.a = 0.0
		return

	var max_ammo: int = weapon.get("max_ammo", 0)
	var loaded := int(floor(ammo + 0.0001))

	# Just the number, unless the mouse is over the counter
	if ammo_hovered:
		ammo_number.text = "%d / %d" % [loaded, max_ammo]
	else:
		ammo_number.text = str(loaded)
	ammo_number.add_theme_color_override("font_color", Color(1.0, 0.35, 0.35) if loaded == 0 else Color.WHITE)

	# The bar shows up while bullets are coming back, and fills toward a full magazine
	var reloading := loaded < max_ammo and reload_pause <= 0.0
	reload_bar.value = ammo / maxf(float(max_ammo), 1.0)
	reload_bar.modulate.a = 1.0 if reloading else 0.0


# Passive reload: bullets come back on their own, but only while you aren't shooting
func update_reload(delta: float) -> void:
	if not is_gun():
		return
	reload_pause -= delta
	var max_ammo := float(weapon.get("max_ammo", 0))
	if reload_pause <= 0.0 and ammo < max_ammo:
		ammo = minf(ammo + float(weapon.get("reload_rate", 1.0)) * delta, max_ammo)


func handle_weapon(delta: float) -> void:
	if Input.is_action_just_pressed("Player_Swap_Weapon"):
		swap_weapon()

	update_reload(delta)

	fire_buffer -= delta
	var mouse_down := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if mouse_down and not mouse_was_down:
		fire_buffer = FIRE_BUFFER_TIME
	mouse_was_down = mouse_down

	# A shot_rate of -1 means the gun keeps firing while the button is held;
	# everything else fires on each click
	var wants_fire := fire_buffer > 0.0
	if is_gun() and int(weapon.get("shot_rate", 1)) == -1:
		wants_fire = mouse_down

	# A melee swing's hit lands after its windup
	if melee_pending:
		melee_windup_left -= delta
		if melee_windup_left <= 0.0:
			melee_pending = false
			melee_hit(melee_aim)

	if wants_fire and gun_cd <= 0.0 and burst_shots_left == 0 and not melee_pending:
		fire_buffer = 0.0
		start_attack()

	# Keep a burst going, one bullet at a time
	if burst_shots_left > 0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			if ammo >= 1.0:
				fire_bullets(1, false)
				burst_shots_left -= 1
				burst_timer = weapon.get("burst_delay", 0.06)
			else:
				# Ran out of ammo partway through the burst
				burst_shots_left = 0

	update_ammo_label()


func start_attack() -> void:
	var cooldown: float = weapon.get("cooldown", 0.3)

	if not is_gun():
		start_melee()
		gun_cd = cooldown
		return

	# Empty gun: just a click, and no reloading is delayed
	if ammo < 1.0:
		gun_cd = DRY_FIRE_DELAY
		return

	var shot_rate: int = weapon.get("shot_rate", 1)
	if shot_rate == -1:
		fire_bullets(1, false)
		gun_cd = cooldown
	elif weapon.get("spread", false):
		# One click fires the whole fan at once, and costs 1 ammo
		fire_bullets(max(shot_rate, 1), true)
		gun_cd = cooldown
	elif shot_rate <= 1:
		fire_bullets(1, false)
		gun_cd = cooldown
	else:
		# A burst: bullets go out one after another, each costing 1 ammo
		var delay: float = weapon.get("burst_delay", 0.06)
		burst_shots_left = shot_rate
		burst_timer = 0.0 # the first bullet goes out right away
		gun_cd = cooldown + delay * shot_rate


# The direction (flat, no up or down) from the player toward the mouse
func get_aim_direction() -> Vector3:
	var cam: Camera3D = $RotateCamera/Hold/Camera3D
	var mousepos := get_viewport().get_mouse_position()
	var ray_origin := cam.project_ray_origin(mousepos)
	var ray_direction := cam.project_ray_normal(mousepos)

	# Find where the mouse ray crosses the height the gun is held at, so aiming
	# is exact no matter which camera angle is used
	var gun_position := global_position + Vector3.UP * GUN_HEIGHT
	var hit = Plane(Vector3.UP, gun_position.y).intersects_ray(ray_origin, ray_direction)

	var aim := Vector3.ZERO
	if hit != null:
		aim = hit - gun_position
	aim.y = 0.0
	if aim.length() < 0.1:
		# Mouse is right on top of the player, so use the way they're facing
		aim = -global_transform.basis.z
		aim.y = 0.0
	return aim.normalized()


# Fires "count" bullets for the price of 1 ammo (used for one bullet, or one shotgun fan).
# fan = true spreads them across the weapon's spread_angle.
func fire_bullets(count: int, fan: bool) -> void:
	ammo = maxf(ammo - 1.0, 0.0)
	reload_pause = weapon.get("reload_delay", 0.6)

	var aim := get_aim_direction()
	var origin := global_position + Vector3.UP * GUN_HEIGHT + aim * MUZZLE_DISTANCE
	var fan_angle: float = weapon.get("spread_angle", 20.0)
	var wobble: float = weapon.get("inaccuracy", 0.0)

	for i in range(count):
		var angle := 0.0
		if fan and count > 1:
			# Fan the pellets evenly across the spread, with a little randomness
			angle = lerpf(-fan_angle / 2.0, fan_angle / 2.0, float(i) / float(count - 1))
			angle += randf_range(-fan_angle * 0.05, fan_angle * 0.05)
		else:
			angle = randf_range(-wobble / 2.0, wobble / 2.0)

		var b = bullet.instantiate()
		get_tree().current_scene.add_child(b)
		b.launch(origin, aim.rotated(Vector3.UP, deg_to_rad(angle)), weapon, light_color)


# Starts a melee swing: aim is locked in now, the lunge starts now, and the hit lands after the windup
func start_melee() -> void:
	melee_aim = get_aim_direction()

	var lunge_distance: float = weapon.get("lunge", 0.0)
	if lunge_distance > 0.0:
		lunge_velocity = melee_aim * (lunge_distance / LUNGE_TIME)
		lunge_time_left = LUNGE_TIME

	var windup: float = weapon.get("windup", 0.0)
	if windup <= 0.0:
		melee_hit(melee_aim)
	else:
		melee_pending = true
		melee_windup_left = windup


# Hits every active enemy inside the swing's range and arc
func melee_hit(aim: Vector3) -> void:
	var reach: float = weapon.get("melee_range", 3.0)
	var arc: float = weapon.get("melee_arc", 120.0)
	var damage = weapon.get("damage", 10)
	var knockback_scale: float = weapon.get("knockback_scale", 1.0)

	show_melee_arc(aim, reach, arc)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.active:
			continue
		var offset: Vector3 = enemy.global_position - global_position
		offset.y = 0.0
		# Enemies are about a tile wide, so let the swing reach a little further for them
		if offset.length() > reach + 0.5:
			continue
		var angle_to_enemy := rad_to_deg(aim.angle_to(offset.normalized()))
		if angle_to_enemy <= arc / 2.0 or offset.length() < 0.6:
			enemy.take_damage(damage, offset.normalized(), knockback_scale)


# A quick fading slash shape so melee swings are visible
func show_melee_arc(aim: Vector3, reach: float, arc: float) -> void:
	var half := deg_to_rad(arc) / 2.0
	var steps := 14
	var verts := PackedVector3Array()
	for i in range(steps):
		var a0 := -half + (half * 2.0) * float(i) / steps
		var a1 := -half + (half * 2.0) * float(i + 1) / steps
		verts.append(Vector3.ZERO)
		verts.append(aim.rotated(Vector3.UP, a0) * reach)
		verts.append(aim.rotated(Vector3.UP, a1) * reach)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.55)
	mesh.surface_set_material(0, material)

	var slash := MeshInstance3D.new()
	slash.mesh = mesh
	get_tree().current_scene.add_child(slash)
	slash.global_position = global_position + Vector3.UP * 0.4

	var tween := create_tween()
	tween.tween_property(material, "albedo_color:a", 0.0, 0.15)
	tween.tween_callback(slash.queue_free)
