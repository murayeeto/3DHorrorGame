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
@export var proximity_detection_range: float = 8.0  # Start chase if player gets this close
@export var field_of_view: float = 120.0
@export var attack_range: float = 2.0

@export_group("Wander")
@export var wander_radius: float = 30.0  # Increased for more map coverage
@export var wander_wait_time_min: float = 1.0  # Reduced idle time
@export var wander_wait_time_max: float = 3.0  # Reduced idle time

@export_group("Hunting")
@export var random_hunt_chance: float = 0.05  # 5% chance per check
@export var hunt_check_interval: float = 3.0  # Check every 3 seconds

# Footstep settings
var footstep_timer: float = 0.0
const FOOTSTEP_INTERVAL: float = 0.6  # Heavy footsteps are slower

# Chase speed ramping
var chase_time: float = 0.0
var current_chase_speed: float = 0.0
const CHASE_SPEED_RAMP_RATE: float = 0.5  # Speed increase per second
const MAX_CHASE_SPEED: float = 8.0  # Maximum chase speed

# Stuck detection
var last_position: Vector3 = Vector3.ZERO
var stuck_timer: float = 0.0
const STUCK_CHECK_INTERVAL: float = 5.0  # Check every 5 seconds (increased)
const STUCK_DISTANCE_THRESHOLD: float = 2.5  # If moved less than this, consider stuck (increased)

# State variables
var current_state: State = State.IDLE
var player: CharacterBody3D = null
var spawn_position: Vector3
var wander_target: Vector3
var state_timer: float = 0.0
var wait_time: float = 3.0
var hunt_timer: float = 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# Child nodes
@onready var navigation_agent: NavigationAgent3D = $NavigationAgent3D
@onready var footstep_player: AudioStreamPlayer3D = null

# Floor-based wandering
var available_floors: Array[Node] = []
var floor_names: Array[String] = [
	"H1Floor", "H2Floor", "H3Floor",  # Hallway floors
	"Floor"  # Room floors
]

func _ready():
	# Add to enemy group for detection
	add_to_group("enemy")
	
	# Store spawn position
	spawn_position = global_position
	last_position = global_position
	
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
	
	# Find all available floors for wandering
	find_floor_nodes()
	
	# Setup footstep audio player
	if not footstep_player:
		footstep_player = AudioStreamPlayer3D.new()
		add_child(footstep_player)
		footstep_player.name = "FootstepPlayer"
		footstep_player.max_distance = 30.0
		footstep_player.volume_db = 0.0
		# Load heavy footstep sound
		var footstep_sound = load("res://Scenes/SFX/heavy-walking-footsteps-352771.mp3")
		if footstep_sound:
			footstep_player.stream = footstep_sound

func _setup():
	# Wait for navigation map to be ready - CRITICAL!
	await get_tree().create_timer(1.0).timeout
	
	# Make sure NavigationAgent is ready and synced
	if navigation_agent:
		NavigationServer3D.map_force_update(navigation_agent.get_navigation_map())
		await get_tree().physics_frame
		await get_tree().physics_frame
	
	# Find player in group
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]
		#print("Enemy found player: ", player.name)
	else:
		pass
		#print("WARNING: No player found in 'player' group!")
	
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
	hunt_timer += delta
	
	# Check for random hunt activation
	if hunt_timer >= hunt_check_interval and current_state != State.CHASE and current_state != State.ATTACK:
		if randf() < random_hunt_chance and player:
			change_state(State.CHASE)
		hunt_timer = 0.0
	
	# Always check for player proximity (even if not in FOV)
	if player and current_state != State.ATTACK:
		var distance_to_player = global_position.distance_to(player.global_position)
		if distance_to_player <= proximity_detection_range:
			change_state(State.CHASE)
	
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
	# Check for timeout
	if state_timer > 30.0:
		change_state(State.IDLE)
		return
	
	# Simple direct movement toward wander target
	var distance_to_target = global_position.distance_to(wander_target)
	
	# Check if reached destination
	if distance_to_target < 2.0:
		change_state(State.IDLE)
		return
	
	# Check if stuck (using collision detection)
	if is_on_wall():
		# Hit a wall, pick a new target
		if state_timer > 2.0:  # Give it 2 seconds before giving up
			change_state(State.IDLE)
			return
	
	# Move directly toward target (same as chase but with wander_speed)
	var direction = (wander_target - global_position).normalized()
	velocity.x = direction.x * wander_speed
	velocity.z = direction.z * wander_speed
	
	# Play footsteps while moving
	play_footsteps(delta)
	
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
	
	# Ramp up chase speed over time
	chase_time += delta
	current_chase_speed = min(chase_speed + (chase_time * CHASE_SPEED_RAMP_RATE), MAX_CHASE_SPEED)
	
	var direction: Vector3
	
	# Update navigation target to player position
	if navigation_agent and navigation_agent.is_target_reachable():
		navigation_agent.target_position = player.global_position
		navigation_agent.max_speed = current_chase_speed
		
		# Use NavigationAgent for pathfinding
		var next_position = navigation_agent.get_next_path_position()
		direction = (next_position - global_position).normalized()
	else:
		# Fallback to direct movement
		direction = (player.global_position - global_position).normalized()
	
	# Set velocity using direction and ramped speed
	velocity.x = direction.x * current_chase_speed
	velocity.z = direction.z * current_chase_speed
	
	# Play footsteps while chasing
	play_footsteps(delta)
	
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
			#print("Enemy: IDLE")
			wait_time = randf_range(wander_wait_time_min, wander_wait_time_max)
		State.WANDER:
			#print("Enemy: WANDER")
			set_random_wander_target()
			if navigation_agent:
				navigation_agent.target_position = wander_target
		State.CHASE:
			#print("Enemy: CHASE")
			chase_time = 0.0
			current_chase_speed = chase_speed
		State.ATTACK:
			#print("Enemy: ATTACK")
			pass

func set_random_wander_target():
	# Use floor-based wandering if floors are available
	if not available_floors.is_empty():
		# Pick a random floor
		var random_floor = available_floors[randi() % available_floors.size()]
		
		# Get a random position on that floor
		var floor_position = get_random_position_on_floor(random_floor)
		
		if floor_position != Vector3.ZERO:
			wander_target = floor_position
			return
	
	# Fallback to old radius-based system if no floors found
	var angle = randf() * TAU
	var distance = randf_range(wander_radius * 0.5, wander_radius)
	var offset = Vector3(
		cos(angle) * distance,
		0,
		sin(angle) * distance
	)
	wander_target = spawn_position + offset

func check_if_stuck(delta: float):
	stuck_timer += delta
	
	if stuck_timer >= STUCK_CHECK_INTERVAL:
		# Check if we've moved enough
		var distance_moved = global_position.distance_to(last_position)
		
		if distance_moved < STUCK_DISTANCE_THRESHOLD:
			# Enemy is stuck! Pick a new wander target
			print("Enemy detected stuck (moved only ", distance_moved, "m in ", STUCK_CHECK_INTERVAL, "s), finding new target")
			set_random_wander_target()
			# Try teleporting slightly if really stuck
			if distance_moved < 0.1:
				global_position.y += 0.5  # Lift up slightly in case clipping through floor
		
		# Reset timer and position
		stuck_timer = 0.0
		last_position = global_position
	

func find_floor_nodes():
	# Search the entire scene tree for floor nodes
	var root = get_tree().root
	for floor_name in floor_names:
		var floors = find_nodes_by_name(root, floor_name)
		available_floors.append_array(floors)
	
	if available_floors.is_empty():
		print("WARNING: Enemy found no floor nodes!")

func find_nodes_by_name(node: Node, search_name: String) -> Array[Node]:
	var result: Array[Node] = []
	if node.name == search_name:
		result.append(node)
	for child in node.get_children():
		result.append_array(find_nodes_by_name(child, search_name))
	return result

func get_random_position_on_floor(floor_node: Node) -> Vector3:
	# Check if it's a CSGBox3D
	var csg_box: CSGBox3D = floor_node as CSGBox3D
	if csg_box:
		# Get the size of the CSG box
		var box_size = csg_box.size
		var global_transform = csg_box.global_transform
		
		# Generate random position within the box's bounds
		var local_pos = Vector3(
			randf_range(-box_size.x / 2.0, box_size.x / 2.0),
			0,
			randf_range(-box_size.z / 2.0, box_size.z / 2.0)
		)
		
		# Transform to global position and set Y to 0 (ground level)
		var global_pos = global_transform * local_pos
		global_pos.y = 0
		
		return global_pos
	
	# Check if it's a MeshInstance3D
	var mesh_instance: MeshInstance3D = floor_node as MeshInstance3D
	if mesh_instance:
		# Get AABB (bounding box) of the mesh
		var aabb = mesh_instance.get_aabb()
		var global_transform = mesh_instance.global_transform
		
		# Generate random position within the floor's bounds
		var local_pos = Vector3(
			randf_range(aabb.position.x, aabb.position.x + aabb.size.x),
			aabb.position.y,
			randf_range(aabb.position.z, aabb.position.z + aabb.size.z)
		)
		
		# Transform to global position and set Y to 0
		var global_pos = global_transform * local_pos
		global_pos.y = 0
		
		return global_pos
	
	return Vector3.ZERO	

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
	pass
	
	# Deal damage if player has take_damage method
	if player and player.has_method("take_damage"):
		player.take_damage(10)
	
	# Add visual/audio feedback here
	# Example: play attack animation, sound effect, etc.

func play_footsteps(delta: float):
	if not footstep_player:
		return
	
	# Update timer
	footstep_timer += delta
	
	# Play footstep sound at intervals
	if footstep_timer >= FOOTSTEP_INTERVAL:
		footstep_timer = 0.0
		footstep_player.play()
		# Stop after 1.5 seconds
		get_tree().create_timer(1.5).timeout.connect(func(): 
			if footstep_player:
				footstep_player.stop()
		)
