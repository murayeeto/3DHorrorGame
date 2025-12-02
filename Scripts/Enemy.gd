extends CharacterBody3D

# State enum
enum State {
	IDLE,
	WANDER,
	CHASE,
	ATTACK
}

# Export variables for easy tweaking
@export_group("Movement")
@export var wander_speed: float = 2.0
@export var chase_speed: float = 5.0
@export var rotation_speed: float = 5.0

@export_group("Detection")
@export var detection_range: float = 15.0
@export var field_of_view: float = 120.0
@export var attack_range: float = 2.0

@export_group("Wander")
@export var wander_radius: float = 10.0
@export var wander_wait_time_min: float = 2.0
@export var wander_wait_time_max: float = 5.0

# State variables
var current_state: State = State.IDLE
var player: CharacterBody3D = null
var spawn_position: Vector3
var wander_target: Vector3
var state_timer: float = 0.0
var wait_time: float = 3.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Child nodes
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D

func _ready():
	# Store spawn position
	spawn_position = global_position
	
	# Configure NavigationAgent - wait for it to be ready
	if navigation_agent:
		# These settings are CRITICAL for proper movement!
		navigation_agent.path_desired_distance = 2.0  # Increased from 0.5
		navigation_agent.target_desired_distance = 2.0  # Increased from 0.5
		navigation_agent.avoidance_enabled = false  # Disable avoidance for simpler movement
		navigation_agent.max_speed = chase_speed
		navigation_agent.path_max_distance = 5.0  # How far ahead to look
	
	# Find player
	call_deferred("_setup")

func _setup():
	# Wait for navigation map to be ready - CRITICAL!
	await get_tree().create_timer(0.5).timeout
	
	# Find player in group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("Enemy found player: ", player.name)
	else:
		print("WARNING: No player found in 'player' group!")
	
	# Start in idle state
	change_state(State.IDLE)

func _physics_process(delta: float):
	# Apply gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	
	# Update state timer
	state_timer += delta
	
	# Always check for player detection (except when attacking)
	if current_state != State.ATTACK and can_see_player():
		change_state(State.CHASE)
	
	# Process current state
	match current_state:
		State.IDLE:
			process_idle(delta)
		State.WANDER:
			process_wander(delta)
		State.CHASE:
			process_chase(delta)
		State.ATTACK:
			process_attack(delta)
	
	# Apply movement
	move_and_slide()

func process_idle(_delta: float):
	# Stop moving
	velocity.x = 0
	velocity.z = 0
	
	# Wait, then start wandering
	if state_timer > wait_time:
		change_state(State.WANDER)

func process_wander(delta: float):
	# Simple direct movement - no navigation agent needed for wandering
	var distance_to_target = global_position.distance_to(wander_target)
	
	print("Wander: Distance to target: ", distance_to_target)
	
	# Check if reached destination
	if distance_to_target < 1.0:
		print("Wander: Reached destination")
		change_state(State.IDLE)
		return
	
	# Move directly towards wander target
	var direction = (wander_target - global_position).normalized()
	
	print("Wander: Target: ", wander_target, " Current: ", global_position, " Direction: ", direction)
	
	# Set velocity directly
	velocity.x = direction.x * wander_speed
	velocity.z = direction.z * wander_speed
	
	# Rotate to face movement direction
	smooth_look_at(wander_target, delta)

func process_chase(delta: float):
	if not player:
		change_state(State.WANDER)
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Check if in attack range
	if distance_to_player <= attack_range:
		change_state(State.ATTACK)
		return
	
	# Check if lost sight of player
	if not can_see_player() and distance_to_player > detection_range * 1.5:
		change_state(State.WANDER)
		return
	
	# Move DIRECTLY towards player - ignore navigation for now
	var direction = (player.global_position - global_position).normalized()
	
	print("Chase: Distance: ", distance_to_player, " Direction: ", direction, " Velocity: ", Vector2(velocity.x, velocity.z))
	
	# Set velocity directly
	velocity.x = direction.x * chase_speed
	velocity.z = direction.z * chase_speed
	
	# Rotate to face player
	smooth_look_at(player.global_position, delta)

func process_attack(delta: float):
	if not player:
		change_state(State.WANDER)
		return
	
	# Stop moving and face player
	velocity.x = 0
	velocity.z = 0
	smooth_look_at(player.global_position, delta)
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Perform attack on interval
	if state_timer > 1.0:
		perform_attack()
		state_timer = 0.0
	
	# Return to chase if player moves away
	if distance_to_player > attack_range * 1.5:
		change_state(State.CHASE)
	elif not can_see_player():
		change_state(State.WANDER)

func change_state(new_state: State):
	# Exit current state
	if current_state == State.WANDER and navigation_agent:
		navigation_agent.target_position = global_position
	
	# Update state
	current_state = new_state
	state_timer = 0.0
	
	# Enter new state
	match new_state:
		State.IDLE:
			print("Enemy: IDLE")
			wait_time = randf_range(wander_wait_time_min, wander_wait_time_max)
		State.WANDER:
			print("Enemy: WANDER")
			set_random_wander_target()
		State.CHASE:
			print("Enemy: CHASE")
		State.ATTACK:
			print("Enemy: ATTACK")

func set_random_wander_target():
	# Pick a random point around spawn position - simple and direct
	var angle = randf() * TAU  # Random angle (0 to 2π)
	var distance = randf_range(wander_radius * 0.3, wander_radius)
	
	var offset = Vector3(
		cos(angle) * distance,
		0,
		sin(angle) * distance
	)
	
	wander_target = spawn_position + offset
	
	print("=== NEW WANDER TARGET ===")
	print("Enemy wandering to: ", wander_target)
	print("Current position: ", global_position)
	print("Distance: ", global_position.distance_to(wander_target))
	print("=========================")

func can_see_player() -> bool:
	if not player:
		return false
	
	var distance = global_position.distance_to(player.global_position)
	
	# Check distance
	if distance > detection_range:
		return false
	
	# Check field of view
	var direction_to_player = (player.global_position - global_position).normalized()
	var forward = -global_transform.basis.z
	var angle = rad_to_deg(forward.angle_to(direction_to_player))
	
	if angle > field_of_view / 2:
		return false
	
	# Check line of sight with raycast
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.5,  # Eye height
		player.global_position + Vector3.UP * 1.0
	)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# Hit something - check if it's the player
		return result.collider == player or result.collider.is_in_group("player")
	
	# No obstruction - can see player
	return true

func smooth_look_at(target_pos: Vector3, delta: float):
	# Get direction to target (ignore Y axis)
	var direction = target_pos - global_position
	direction.y = 0
	
	if direction.length() < 0.01:
		return
	
	direction = direction.normalized()
	
	# Calculate target rotation
	var target_rotation = atan2(direction.x, direction.z)
	
	# Smoothly interpolate rotation
	rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func perform_attack():
	print("Enemy attacks!")
	
	# Deal damage if player has take_damage method
	if player and player.has_method("take_damage"):
		player.take_damage(10)
	
	# Add visual/audio feedback here
	# Example: play attack animation, sound effect, etc.
