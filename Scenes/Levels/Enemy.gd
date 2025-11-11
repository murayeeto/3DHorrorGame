extends Node3D

# State enum
enum State {
	IDLE,
	WANDER,
	INVESTIGATE,
	CHASE,
	ATTACK,
	LOSE_PLAYER
}

# Export variables for easy tweaking
@export_group("Movement")
@export var wander_speed: float = 2.0
@export var chase_speed: float = 5.0
@export var rotation_speed: float = 5.0

@export_group("Detection")
@export var detection_range: float = 15.0
@export var lose_sight_range: float = 20.0
@export var field_of_view: float = 120.0  # degrees
@export var attack_range: float = 2.0

@export_group("Wander")
@export var wander_radius: float = 10.0
@export var wander_wait_time: float = 3.0
@export var wander_move_time: float = 5.0

@export_group("Investigation")
@export var investigation_duration: float = 5.0
@export var last_known_position_threshold: float = 1.0

# State variables
var current_state: State = State.IDLE
var player: Node3D = null
var spawn_position: Vector3
var wander_target: Vector3
var last_known_player_position: Vector3
var state_timer: float = 0.0
var move_target: Vector3

# Child nodes - assign these in the editor or create them here
var navigation_agent: NavigationAgent3D
var ray_cast: RayCast3D
var character_body: CharacterBody3D  # Reference to child CharacterBody3D if you have one
var enemy_model: Node3D  # Reference to the visual model node

func _ready():
	spawn_position = global_position
	
	# Try to find CharacterBody3D child (if exists)
	for child in get_children():
		if child is CharacterBody3D:
			character_body = child
			break
		# Find the Enemy visual node
		if child.name == "Enemy":
			enemy_model = child
	
	# Setup NavigationAgent3D
	navigation_agent = NavigationAgent3D.new()
	add_child(navigation_agent)
	navigation_agent.path_desired_distance = 0.5
	navigation_agent.target_desired_distance = 0.5
	navigation_agent.avoidance_enabled = true
	navigation_agent.radius = 0.5
	navigation_agent.height = 2.0
	
	# Setup RayCast3D for line of sight
	ray_cast = RayCast3D.new()
	add_child(ray_cast)
	ray_cast.target_position = Vector3.FORWARD * detection_range
	ray_cast.collision_mask = 1  # Adjust based on your collision layers
	ray_cast.enabled = true
	
	# Find player (assumes player is in group "player")
	call_deferred("find_player")
	
	# Wait for navigation to be ready
	await get_tree().physics_frame
	change_state(State.IDLE)

func find_player():
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		print("Enemy found player: ", player.name)

func _physics_process(delta):
	state_timer += delta
	
	# State machine logic
	match current_state:
		State.IDLE:
			process_idle(delta)
		State.WANDER:
			process_wander(delta)
		State.INVESTIGATE:
			process_investigate(delta)
		State.CHASE:
			process_chase(delta)
		State.ATTACK:
			process_attack(delta)
		State.LOSE_PLAYER:
			process_lose_player(delta)

func process_idle(delta):
	# Check for player
	if can_see_player():
		change_state(State.CHASE)
	elif state_timer > wander_wait_time:
		change_state(State.WANDER)

func process_wander(delta):
	print("WANDER - Nav finished: ", navigation_agent.is_navigation_finished(), " Target: ", navigation_agent.target_position)
	
	if not navigation_agent.is_navigation_finished():
		move_to_target(wander_speed, delta)
	else:
		# Reached wander point, go back to idle
		change_state(State.IDLE)
	
	# Check for player
	if can_see_player():
		change_state(State.CHASE)

func process_investigate(delta):
	var distance_to_last_known = global_position.distance_to(last_known_player_position)
	
	if can_see_player():
		change_state(State.CHASE)
	elif distance_to_last_known < last_known_position_threshold:
		# Reached last known position, look around
		if state_timer > investigation_duration:
			change_state(State.WANDER)
	else:
		# Move to last known position
		navigation_agent.target_position = last_known_player_position
		move_to_target(chase_speed * 0.7, delta)

func process_chase(delta):
	if not player:
		change_state(State.WANDER)
		return
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	print("CHASE - Distance to player: ", distance_to_player, " Can see: ", can_see_player())
	
	if distance_to_player < attack_range:
		change_state(State.ATTACK)
	elif not can_see_player() and distance_to_player > detection_range:
		change_state(State.LOSE_PLAYER)
	else:
		# Update last known position
		if can_see_player():
			last_known_player_position = player.global_position
		
		# Chase the player
		navigation_agent.target_position = player.global_position
		print("Target set to: ", navigation_agent.target_position, " Nav finished: ", navigation_agent.is_navigation_finished())
		move_to_target(chase_speed, delta)

func process_attack(delta):
	if not player:
		change_state(State.WANDER)
		return
	
	# Stop moving and face player
	look_at_target(player.global_position, delta)
	
	var distance_to_player = global_position.distance_to(player.global_position)
	
	# Perform attack (implement your attack logic here)
	if state_timer > 1.0:  # Attack cooldown
		perform_attack()
		state_timer = 0.0
	
	# Return to chase if player moves away
	if distance_to_player > attack_range * 1.5:
		change_state(State.CHASE)

func process_lose_player(delta):
	# Move to last known position
	navigation_agent.target_position = last_known_player_position
	move_to_target(chase_speed * 0.8, delta)
	
	if can_see_player():
		change_state(State.CHASE)
	elif global_position.distance_to(last_known_player_position) < last_known_position_threshold:
		change_state(State.INVESTIGATE)

func change_state(new_state: State):
	# Exit current state
	match current_state:
		State.IDLE:
			pass
		State.WANDER:
			pass
		State.CHASE:
			pass
	
	# Enter new state
	current_state = new_state
	state_timer = 0.0
	
	match new_state:
		State.IDLE:
			print("Enemy: IDLE")
		State.WANDER:
			print("Enemy: WANDER")
			set_random_wander_target()
		State.INVESTIGATE:
			print("Enemy: INVESTIGATE")
		State.CHASE:
			print("Enemy: CHASE")
		State.ATTACK:
			print("Enemy: ATTACK")
		State.LOSE_PLAYER:
			print("Enemy: LOSE_PLAYER")

func can_see_player() -> bool:
	if not player:
		return false
	
	var distance = global_position.distance_to(player.global_position)
	if distance > detection_range:
		return false
	
	# Check field of view
	var direction_to_player = (player.global_position - global_position).normalized()
	var forward = -global_transform.basis.z
	var angle = rad_to_deg(forward.angle_to(direction_to_player))
	
	if angle > field_of_view / 2:
		return false
	
	# Line of sight check
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 1.0,  # Eye height
		player.global_position + Vector3.UP * 1.0
	)
	query.exclude = [self]
	if character_body:
		query.exclude.append(character_body)
	
	var result = space_state.intersect_ray(query)
	
	if result:
		var collider = result.collider
		return collider == player or collider.is_in_group("player")
	
	# No collision means clear line of sight
	return true

func move_to_target(speed: float, delta: float):
	if not navigation_agent.is_target_reachable():
		print("WARNING: Target is not reachable!")
		return
		
	if navigation_agent.is_navigation_finished():
		print("Navigation finished - reached target")
		return
	
	var next_position = navigation_agent.get_next_path_position()
	var current_pos = global_position
	var direction = (next_position - current_pos).normalized()
	
	print("Moving - Current: ", current_pos, " Next: ", next_position, " Direction: ", direction, " Speed: ", speed)
	
	# Move the Node3D directly
	var movement = direction * speed * delta
	global_position += movement
	print("New position: ", global_position, " Movement applied: ", movement)
	
	# Rotate to face movement direction
	look_at_target(global_position + direction, delta)

func look_at_target(target_pos: Vector3, delta: float):
	var direction = (target_pos - global_position)
	direction.y = 0
	direction = direction.normalized()
	
	if direction.length() > 0.01:
		var target_rotation = atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_rotation, rotation_speed * delta)

func set_random_wander_target():
	var random_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
	var random_distance = randf_range(wander_radius * 0.5, wander_radius)
	
	wander_target = spawn_position + Vector3(
		random_direction.x * random_distance,
		0,
		random_direction.y * random_distance
	)
	
	navigation_agent.target_position = wander_target

func perform_attack():
	print("Enemy attacking player!")
	# Implement your attack logic here
	# Example: apply damage to player
	if player and player.has_method("take_damage"):
		player.take_damage(10)
	
	# You could also emit a signal or play an animation
	# emit_signal("attacked_player")

# Optional: Add debug visualization
func _process(_delta):
	if OS.is_debug_build():
		# You can add debug draw calls here if needed
		pass
