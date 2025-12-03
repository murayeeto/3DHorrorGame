extends CharacterBody3D

# Signals
signal health_changed(new_health: int)

# Movement speeds
const WALK_SPEED = 5.0
const SPRINT_SPEED = 8.0
const CROUCH_SPEED = 2.5
const ACCELERATION = 10.0
const DECELERATION = 12.0
const JUMP_VELOCITY = 4.5

# Crouch settings
const CROUCH_HEIGHT = 0.5
const STAND_HEIGHT = 1.0
const CROUCH_TRANSITION_SPEED = 10.0

# Head bob settings
const BOB_FREQUENCY = 2.0
const BOB_AMPLITUDE = 0.08
const BOB_AMPLITUDE_SPRINT = 0.12

# Item pickup settings
const PICKUP_RANGE = 3.0
const INTERACTION_RANGE = 3.0

# Health settings
const MAX_HEALTH = 3
const INVULNERABILITY_TIME = 2.0

# Debug settings
var show_book_debug: bool = false
var debug_spheres: Array = []

# Footstep settings
var footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL_WALK: float = 0.5
const FOOTSTEP_INTERVAL_SPRINT: float = 0.35
const FOOTSTEP_INTERVAL_CROUCH: float = 0.7

# State variables
var current_speed = WALK_SPEED
var is_crouching = false
var head_bob_time = 0.0
var health = MAX_HEALTH
var is_invulnerable = false
var invulnerability_timer = 0.0

# Static effect variables
var static_intensity: float = 0.0
const STATIC_MAX_DISTANCE: float = 15.0  # Distance at which static starts (reduced)
const STATIC_MIN_DISTANCE: float = 3.0   # Distance at which static is max (reduced)

# Node references
@onready var camera = $Head/Camera3D
@onready var collision_shape = $CollisionShape3D
@onready var raycast: RayCast3D = null
@onready var footstep_player: AudioStreamPlayer3D = null
@onready var static_overlay: Control = null
@onready var static_audio: AudioStreamPlayer = null
@onready var ambient_audio: AudioStreamPlayer = null

# Original heights for transitions
var original_camera_y = 0.0
var target_camera_y = 0.0

func _ready():
	# Store original camera height
	if camera:
		original_camera_y = camera.position.y
		target_camera_y = original_camera_y
	
	# Setup raycast for item pickup
	if not raycast:
		raycast = RayCast3D.new()
		camera.add_child(raycast)
		raycast.name = "InteractionRay"
	
	raycast.enabled = true
	raycast.target_position = Vector3(0, 0, -PICKUP_RANGE)
	raycast.collision_mask = 2  # Set to layer 2 for interactable objects
	
	# Setup footstep audio player
	if not footstep_player:
		footstep_player = AudioStreamPlayer3D.new()
		add_child(footstep_player)
		footstep_player.name = "FootstepPlayer"
		footstep_player.max_distance = 20.0
		footstep_player.volume_db = -5.0
		# Load footstep sound
		var footstep_sound = load("res://Scenes/SFX/walking-sound-effect-272246.mp3")
		if footstep_sound:
			footstep_player.stream = footstep_sound
	
	# Setup static overlay
	if not static_overlay:
		# Find or create a CanvasLayer for the static overlay
		var canvas_layer = CanvasLayer.new()
		add_child(canvas_layer)
		canvas_layer.name = "StaticCanvasLayer"
		canvas_layer.layer = 100  # Draw on top of everything
		
		# Create a Control container for the animated sprite
		var control_container = Control.new()
		canvas_layer.add_child(control_container)
		control_container.set_anchors_preset(Control.PRESET_FULL_RECT)
		control_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		# Load and set static animation
		var static_frames = load("res://Scenes/Resources/static-tv-static.gif")
		if static_frames:
			var animated_sprite = AnimatedSprite2D.new()
			control_container.add_child(animated_sprite)
			animated_sprite.sprite_frames = static_frames
			animated_sprite.play("default")
			animated_sprite.centered = true
			# Position at center of screen and scale to fill
			animated_sprite.position = Vector2(960, 540)  # 1920x1080 center
			animated_sprite.scale = Vector2(20, 20)  # Large scale to cover screen
		
		static_overlay = control_container
		# Start invisible
		static_overlay.modulate.a = 0.0
	
	# Setup static audio
	if not static_audio:
		static_audio = AudioStreamPlayer.new()
		add_child(static_audio)
		static_audio.name = "StaticAudio"
		static_audio.bus = "Master"
		# Load static sound
		var static_sound = load("res://Scenes/SFX/Slender Man Static - Sound Effect.mp3")
		if static_sound:
			static_audio.stream = static_sound
			static_audio.volume_db = -80.0  # Start silent
	
	# Setup ambient horror audio
	if not ambient_audio:
		ambient_audio = AudioStreamPlayer.new()
		add_child(ambient_audio)
		ambient_audio.name = "AmbientAudio"
		ambient_audio.bus = "Master"
		# Load ambient sound
		var ambient_sound = load("res://Scenes/SFX/horror-ambience-01-66708.mp3")
		if ambient_sound:
			ambient_audio.stream = ambient_sound
			ambient_audio.volume_db = -20.0  # Low volume for ambience
			ambient_audio.autoplay = true
			ambient_audio.play()

func _physics_process(delta: float) -> void:
	# Apply gravity
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Update invulnerability timer
	if is_invulnerable:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0:
			is_invulnerable = false
			print("Invulnerability ended")
	
	# Check for enemy collision damage
	check_enemy_collision()
	
	# Update static effect based on enemy proximity
	update_static_effect()
	
	# Handle crouch toggle
	handle_crouch(delta)
	
	# Handle jump
	if Input.is_action_just_pressed("Jump") and is_on_floor() and not is_crouching:
		velocity.y = JUMP_VELOCITY
	
	# Get movement input
	var input_dir := Input.get_vector("Left", "Right", "Forward", "Backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# Determine current speed based on state
	update_movement_speed()
	
	# Apply movement with acceleration/deceleration
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * current_speed, ACCELERATION * delta)
		velocity.z = move_toward(velocity.z, direction.z * current_speed, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0, DECELERATION * delta)
	
	# Apply head bob
	if is_on_floor() and direction:
		apply_head_bob(delta)
		play_footsteps(delta)
	else:
		# Reset footstep timer when not moving
		footstep_timer = 0.0
	
	move_and_slide()

func _input(event):
	# Debug - show books through walls
	if event.is_action_pressed("DebugStuff"):
		toggle_book_debug()
	
	# Handle item pickup/interaction
	if event.is_action_pressed("Interact"):
		attempt_pickup()

func handle_crouch(delta: float):
	# Toggle crouch
	if Input.is_action_just_pressed("Crouch"):
		is_crouching = not is_crouching
		
		if is_crouching:
			target_camera_y = original_camera_y * CROUCH_HEIGHT
			# Optionally adjust collision shape here if needed
		else:
			# Check if there's room to stand up
			if can_stand_up():
				target_camera_y = original_camera_y
			else:
				is_crouching = true  # Stay crouched
	
	# Smoothly transition camera height
	if camera:
		camera.position.y = lerp(camera.position.y, target_camera_y, CROUCH_TRANSITION_SPEED * delta)

func can_stand_up() -> bool:
	# Simple raycast check above player to see if there's room to stand
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position + Vector3.UP * 2.0
	)
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func update_movement_speed():
	if is_crouching:
		current_speed = CROUCH_SPEED
	elif Input.is_action_pressed("Sprint") and not is_crouching:
		current_speed = SPRINT_SPEED
	else:
		current_speed = WALK_SPEED

func apply_head_bob(delta: float):
	if not camera:
		return
	
	head_bob_time += delta * velocity.length()
	
	var bob_amount = BOB_AMPLITUDE
	if current_speed == SPRINT_SPEED:
		bob_amount = BOB_AMPLITUDE_SPRINT
	elif is_crouching:
		bob_amount = BOB_AMPLITUDE * 0.5
	
	# Apply vertical bob
	var bob_offset = sin(head_bob_time * BOB_FREQUENCY) * bob_amount
	camera.position.y = target_camera_y + bob_offset

func play_footsteps(delta: float):
	if not footstep_player:
		return
	
	# Determine footstep interval based on movement speed
	var interval = FOOTSTEP_INTERVAL_WALK
	if is_crouching:
		interval = FOOTSTEP_INTERVAL_CROUCH
	elif current_speed == SPRINT_SPEED:
		interval = FOOTSTEP_INTERVAL_SPRINT
	
	# Update timer
	footstep_timer += delta
	
	# Play footstep sound at intervals
	if footstep_timer >= interval:
		footstep_timer = 0.0
		# Stop any currently playing sound to prevent overlap
		if footstep_player.playing:
			footstep_player.stop()
		# Play from the beginning and stop after 1.5 seconds
		footstep_player.play(0.0)
		get_tree().create_timer(1.5).timeout.connect(func(): 
			if footstep_player and footstep_player.playing:
				footstep_player.stop()
		)

func attempt_pickup():
	if not raycast:
		return
	
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider = raycast.get_collider()
		
		# Check if the object has a pickup method
		if collider.has_method("pickup"):
			collider.pickup(self)
			print("Picked up: ", collider.name)
		# Or check for interaction method
		elif collider.has_method("interact"):
			collider.interact(self)
			print("Interacted with: ", collider.name)
		else:
			print("Object cannot be picked up: ", collider.name)
			
# Helper function for items to call when picked up
func add_to_inventory(item_name: String):
	print("Added to inventory: ", item_name)
	# TODO: Implement actual inventory system
	pass

# Check for collision with enemies
func check_enemy_collision():
	if is_invulnerable:
		return
	
	# Check all bodies we're colliding with
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Check if collider is an enemy (has CharacterBody3D parent or is enemy)
		if collider and (collider.is_in_group("enemy") or collider.name.contains("Enemy")):
			take_damage(1)
			break

# Take damage function
func take_damage(amount: int):
	if is_invulnerable:
		return
	
	health -= amount
	print("Player took damage! Health: ", health, "/", MAX_HEALTH)
	
	# Emit signal for UI update
	health_changed.emit(health)
	
	# Check if dead
	if health <= 0:
		die()
		return
	
	# Start invulnerability only if still alive
	is_invulnerable = true
	invulnerability_timer = INVULNERABILITY_TIME
	
	# Visual feedback - flash the screen or camera
	if camera:
		# Create a brief camera shake or flash effect
		camera_damage_effect()

func camera_damage_effect():
	# Simple camera shake effect
	if camera:
		var original_pos = camera.position
		# Quick shake
		for i in range(3):
			camera.position = original_pos + Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), 0)
			await get_tree().create_timer(0.05).timeout
		camera.position = original_pos

# DEBUG FUNCTIONS
func toggle_book_debug():
	show_book_debug = !show_book_debug
	print("========================================")
	if show_book_debug:
		print("DEBUG: SHOWING BOOKS - ON")
		create_book_markers()
	else:
		print("DEBUG: HIDING BOOKS - OFF")
		clear_book_markers()
	print("========================================")

func create_book_markers():
	clear_book_markers()
	var collectibles = get_tree().get_nodes_in_group("collectibles")
	print("Found ", collectibles.size(), " books")
	
	for collectible in collectibles:
		var mesh_instance = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 2.0
		sphere_mesh.height = 4.0
		mesh_instance.mesh = sphere_mesh
		
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(1.0, 0.0, 1.0, 0.9)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.0, 1.0)
		material.emission_energy_multiplier = 5.0
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.no_depth_test = true
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		
		mesh_instance.material_override = material
		get_tree().root.add_child(mesh_instance)
		mesh_instance.global_position = collectible.global_position
		debug_spheres.append(mesh_instance)
		print("Created marker at ", collectible.global_position)

func clear_book_markers():
	for sphere in debug_spheres:
		if is_instance_valid(sphere):
			sphere.queue_free()
	debug_spheres.clear()

func die():
	print("========== PLAYER DIED ==========")
	print("Game Over!")
	# Load the game over screen immediately
	get_tree().change_scene_to_file("res://Scenes/Menus&Screens/GameOver.tscn")

func update_static_effect():
	# Check if we're still in the scene tree
	if not is_inside_tree():
		return
	
	# Find nearest enemy
	var enemies = get_tree().get_nodes_in_group("enemy")
	if enemies.is_empty():
		# No enemies - fade out static
		static_intensity = lerp(static_intensity, 0.0, 0.1)
		update_static_visuals()
		return
	
	# Find closest enemy
	var closest_distance = INF
	for enemy in enemies:
		var distance = global_position.distance_to(enemy.global_position)
		if distance < closest_distance:
			closest_distance = distance
	
	# Don't show static during invulnerability
	if is_invulnerable:
		static_intensity = 0.0
		update_static_visuals()
		return
	
	# Calculate intensity based on distance
	if closest_distance > STATIC_MAX_DISTANCE:
		# Too far - no static, fade out quickly
		static_intensity = lerp(static_intensity, 0.0, 0.2)
	elif closest_distance < STATIC_MIN_DISTANCE:
		# Very close - max static
		static_intensity = lerp(static_intensity, 1.0, 0.05)
	else:
		# Interpolate based on distance
		var normalized_distance = (closest_distance - STATIC_MIN_DISTANCE) / (STATIC_MAX_DISTANCE - STATIC_MIN_DISTANCE)
		var target_intensity = 1.0 - normalized_distance
		static_intensity = lerp(static_intensity, target_intensity, 0.05)
	
	update_static_visuals()

func update_static_visuals():
	# Update overlay transparency
	if static_overlay and is_instance_valid(static_overlay):
		static_overlay.modulate.a = static_intensity * 0.25  # Max 25% opacity (reduced from 60%)
		static_overlay.visible = static_intensity > 0.05  # Only show when noticeable
	
	# Update audio volume
	if static_audio and is_instance_valid(static_audio):
		if static_intensity > 0.01:
			if not static_audio.playing:
				static_audio.play()
			# Volume range from -80 dB (silent) to -10 dB (loud)
			var target_volume = lerp(-80.0, -10.0, static_intensity)
			static_audio.volume_db = target_volume
		else:
			if static_audio.playing:
				static_audio.stop()
