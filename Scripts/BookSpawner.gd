extends Node

@export var book_scene: PackedScene  # Assign bookCollect.tscn in the editor
@export var number_of_books: int = 8
@export var spawn_height: float = 2.5  # Height above floor to spawn books
@export var min_distance_between_books: float = 10.0  # Minimum distance between spawned books
@export var max_spawn_attempts: int = 1000  # Max attempts per book

# List of floor node names to spawn on
var floor_names: Array[String] = [
	"H1Floor", "H2Floor", "H3Floor",  # Hallway floors
	"Floor"  # Room floors (will match all Floor nodes)
]

func _ready():
	# Wait for scene to be fully loaded
	await get_tree().process_frame
	spawn_books()

var spawned_positions: Array[Vector3] = []
var available_floors: Array[Node] = []

func spawn_books():
	if not book_scene:
		print("ERROR: Book scene not assigned to BookSpawner!")
		return
	
	# Find all floor nodes in the scene
	find_floor_nodes()
	
	if available_floors.is_empty():
		print("ERROR: No floor nodes found! Looking for: ", floor_names)
		return
	
	print("Found ", available_floors.size(), " floor nodes")
	
	var spawned_count = 0
	
	for i in range(number_of_books):
		var spawned = false
		
		for attempt in range(max_spawn_attempts):
			# Pick a random floor
			var random_floor = available_floors[randi() % available_floors.size()]
			
			# Get a random position on that floor
			var spawn_position = get_random_position_on_floor(random_floor)
			
			if spawn_position != Vector3.ZERO and is_far_enough_from_other_books(spawn_position):
				# Instance the book
				var book = book_scene.instantiate()
				
				# Set unique ID and name
				book.collectible_id = i + 1
				book.collectible_name = "Book" + str(i + 1)
				
				# Add to scene
				get_parent().add_child(book)
				
				# Position the book
				book.global_position = spawn_position
				
				# Scale down the book
				book.scale = Vector3(0.05, 0.05, 0.05)
				
				# Disable bobbing animation
				if book.has_method("set_physics_process"):
					book.set_physics_process(false)
				
				# Store position and mark spawned
				spawned_positions.append(spawn_position)
				spawned = true
				spawned_count += 1
				break
		
		if not spawned:
			print("WARNING: Failed to spawn book ", i + 1)
	
	print("Successfully spawned ", spawned_count, "/", number_of_books, " books")

func find_floor_nodes():
	# Search the entire scene tree for floor nodes
	var root = get_tree().root
	for floor_name in floor_names:
		var floors = find_nodes_by_name(root, floor_name)
		available_floors.append_array(floors)

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
		
		# Transform to global position and set spawn height
		var global_pos = global_transform * local_pos
		global_pos.y = spawn_height
		
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
		
		# Transform to global position and set spawn height
		var global_pos = global_transform * local_pos
		global_pos.y = spawn_height
		
		return global_pos
	
	print("  ERROR: Floor node is neither CSGBox3D nor MeshInstance3D: ", floor_node.name)
	return Vector3.ZERO

func is_far_enough_from_other_books(position: Vector3) -> bool:
	for spawned_pos in spawned_positions:
		var distance = position.distance_to(spawned_pos)
		if distance < min_distance_between_books:
			return false
	return true
