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

# State variables
var current_speed = WALK_SPEED
var is_crouching = false
var head_bob_time = 0.0
var health = MAX_HEALTH
var is_invulnerable = false
var invulnerability_timer = 0.0

# Node references
@onready var camera = $Head/Camera3D
@onready var collision_shape = $CollisionShape3D
@onready var raycast: RayCast3D = null

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
	
	move_and_slide()

func _input(event):
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
	
	# Start invulnerability
	is_invulnerable = true
	invulnerability_timer = INVULNERABILITY_TIME
	
	# Visual feedback - flash the screen or camera
	if camera:
		# Create a brief camera shake or flash effect
		camera_damage_effect()
	
	# Check if dead
	if health <= 0:
		die()

func camera_damage_effect():
	# Simple camera shake effect
	if camera:
		var original_pos = camera.position
		# Quick shake
		for i in range(3):
			camera.position = original_pos + Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), 0)
			await get_tree().create_timer(0.05).timeout
		camera.position = original_pos
		
		print("[DAMAGE] Invulnerable for ", INVULNERABILITY_TIME, " seconds")

func die():
	print("========== PLAYER DIED ==========")
	print("Game Over!")
	# TODO: Implement death screen/respawn
	# For now, just reload the scene
	await get_tree().create_timer(1.0).timeout
	get_tree().reload_current_scene()
