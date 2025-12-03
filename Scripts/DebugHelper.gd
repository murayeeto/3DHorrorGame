extends Node

# Toggle to show/hide book locations through walls
var show_books_through_walls: bool = false

# Store reference to created debug meshes
var debug_spheres: Array = []

func _ready():
	print("========================================")
	print("DebugHelper LOADED - Press DebugStuff key to toggle")
	print("========================================")
	# Process input before other nodes
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -100  # Process before everything else

func _input(event):
	if event.is_action_pressed("DebugStuff"):
		print("DEBUG: DebugStuff action detected!")
		toggle_book_visibility()
		get_viewport().set_input_as_handled()

func _process(_delta):
	# Update marker positions each frame (in case books are bobbing)
	if show_books_through_walls:
		var collectibles = get_tree().get_nodes_in_group("collectibles")
		var valid_collectibles = []
		
		for collectible in collectibles:
			if collectible is Collectible and not collectible.is_collected:
				valid_collectibles.append(collectible)
		
		# If number of markers doesn't match collectibles, refresh
		if debug_spheres.size() != valid_collectibles.size():
			create_debug_markers()
		else:
			# Update positions
			for i in range(min(debug_spheres.size(), valid_collectibles.size())):
				if is_instance_valid(debug_spheres[i]) and is_instance_valid(valid_collectibles[i]):
					debug_spheres[i].global_position = valid_collectibles[i].global_position

func toggle_book_visibility():
	show_books_through_walls = !show_books_through_walls
	
	if show_books_through_walls:
		print("========================================")
		print("DEBUG: SHOWING BOOKS THROUGH WALLS - ON")
		print("========================================")
		create_debug_markers()
	else:
		print("========================================")
		print("DEBUG: HIDING DEBUG MARKERS - OFF")
		print("========================================")
		clear_debug_markers()

func create_debug_markers():
	# Clear any existing markers first
	clear_debug_markers()
	
	# Find all collectibles
	var collectibles = get_tree().get_nodes_in_group("collectibles")
	print("DEBUG: Found ", collectibles.size(), " collectibles")
	
	for collectible in collectibles:
		if collectible is Collectible and not collectible.is_collected:
			# Create a bright sphere mesh that renders through walls
			var mesh_instance = MeshInstance3D.new()
			var sphere_mesh = SphereMesh.new()
			sphere_mesh.radius = 1.5  # Much bigger sphere
			sphere_mesh.height = 3.0
			
			mesh_instance.mesh = sphere_mesh
			
			# Create material that shows through walls
			var material = StandardMaterial3D.new()
			material.albedo_color = Color(1.0, 0.0, 1.0, 0.9)  # Bright magenta/pink
			material.emission_enabled = true
			material.emission = Color(1.0, 0.0, 1.0)
			material.emission_energy_multiplier = 5.0  # Much brighter
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			material.no_depth_test = true  # This makes it render through walls
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED  # Visible from all angles
			
			mesh_instance.material_override = material
			mesh_instance.layers = 1  # Make sure it's on a visible layer
			
			# Add to scene at collectible position
			get_tree().root.add_child(mesh_instance)
			mesh_instance.global_position = collectible.global_position
			
			# Store reference
			debug_spheres.append(mesh_instance)
			
			print("DEBUG: Created marker for ", collectible.collectible_name, " at ", collectible.global_position)

func clear_debug_markers():
	for sphere in debug_spheres:
		if is_instance_valid(sphere):
			sphere.queue_free()
	debug_spheres.clear()
