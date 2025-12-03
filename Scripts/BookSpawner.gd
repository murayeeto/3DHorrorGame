extends Node

@export var book_scene: PackedScene  # Assign bookCollect.tscn in the editor
@export var number_of_books: int = 8
@export var spawn_height: float = 1.0  # Height above floor to spawn books

# Define spawn area bounds (adjust these based on your map)
@export var min_x: float = -500.0
@export var max_x: float = 500.0
@export var min_z: float = -500.0
@export var max_z: float = 500.0
@export var floor_y: float = 0.0  # The Y position of your floor

# Spawn validation settings
@export var max_spawn_attempts: int = 1000  # Max attempts to find valid position per book
@export var raycast_height: float = 10.0  # How high above to start raycast
@export var min_clearance: float = 1.5  # Minimum height clearance above spawn point
@export var min_distance_between_books: float = 10.0  # Minimum distance between spawned books
@export var corner_buffer: float = 10.0  # Don't spawn within this distance of corners (min/max bounds)

func _ready():
	# Wait for scene to be fully loaded
	await get_tree().process_frame
	spawn_books()

var spawned_positions: Array[Vector3] = []

func spawn_books():
	if not book_scene:
		print("ERROR: Book scene not assigned to BookSpawner!")
		return
	
	print("Spawning ", number_of_books, " books...")
	
	var spawned_count = 0
	
	for i in range(number_of_books):
		print("\n=== Spawning book ", i + 1, "/", number_of_books, " ===")
		var spawned = false
		
		for attempt in range(max_spawn_attempts):
			# Generate random position
			var random_x = randf_range(min_x + corner_buffer, max_x - corner_buffer)
			var random_z = randf_range(min_z + corner_buffer, max_z - corner_buffer)
			var test_position = Vector3(random_x, raycast_height, random_z)
			
			# Raycast down to find floor
			var floor_position = find_floor_position(test_position)
			
			if floor_position != Vector3.ZERO and is_far_enough_from_other_books(floor_position):
				# Instance the book
				var book = book_scene.instantiate()
				
				# Set unique ID and name
				book.collectible_id = i + 1
				book.collectible_name = "Book" + str(i + 1)
				
				# Add to scene
				get_parent().add_child(book)
				
				# Set position and scale after adding to scene
				book.global_position = floor_position
				book.scale = Vector3(0.05, 0.05, 0.05)
				
				# Disable bobbing animation
				if book.has_method("set_physics_process"):
					book.set_physics_process(false)
				
				# Store this position
				spawned_positions.append(floor_position)
				spawned = true
				spawned_count += 1
				print("  SUCCESS! Book ", i + 1, " spawned at ", floor_position)
				break
		
		if not spawned:
			print("  FAILED to spawn book ", i + 1, " after ", max_spawn_attempts, " attempts")
	
	print("\n=== SPAWN SUMMARY ===")
	print("Successfully spawned ", spawned_count, " out of ", number_of_books, " books")
	if spawned_count < number_of_books:
		print("WARNING: Some books failed to spawn!")
	for i in range(spawned_positions.size()):
		print("  Book ", i + 1, ": ", spawned_positions[i])



func is_far_enough_from_other_books(position: Vector3) -> bool:
	for spawned_pos in spawned_positions:
		var distance = position.distance_to(spawned_pos)
		if distance < min_distance_between_books:
			return false
	return true

func find_floor_position(position: Vector3) -> Vector3:
	var space_state = get_tree().root.get_world_3d().direct_space_state
	
	# First raycast DOWN to find floor
	var ray_down = PhysicsRayQueryParameters3D.create(position, position + Vector3(0, -50.0, 0))
	var result_down = space_state.intersect_ray(ray_down)
	
	if not result_down:
		return Vector3.ZERO  # No floor found
	
	# Second raycast UP from floor to check if there's a ceiling (we're inside)
	var check_position = Vector3(result_down.position.x, 2.5, result_down.position.z)
	var ray_up = PhysicsRayQueryParameters3D.create(check_position, check_position + Vector3(0, 1000.0, 0))
	var result_up = space_state.intersect_ray(ray_up)
	
	if not result_up:
		return Vector3.ZERO  # No ceiling found - probably outside
	
	# Check if ceiling is at least 2 units high (less strict)
	var ceiling_height = result_up.position.y - 2.5
	if ceiling_height < 2.0:
		return Vector3.ZERO  # Ceiling too low
	
	# Always spawn at Y = 2.5, use detected X and Z position
	return Vector3(result_down.position.x, 2.5, result_down.position.z)