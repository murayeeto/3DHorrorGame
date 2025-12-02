extends Node
class_name CollectibleManager

# Signals
signal collectible_found(id: int, name: String, current: int, total: int)
signal all_collectibles_found()

# Export variables
@export var total_collectibles: int = 8  # Like Slenderman's 8 pages
@export var show_ui: bool = true
@export var game_over_on_complete: bool = false

# State variables
var collected_ids: Array[int] = []
var collected_count: int = 0

# UI reference
var ui_label: Label = null

func _ready():
	# Add to group for easy access
	add_to_group("collectible_manager")
	
	# Find all collectibles in the scene
	call_deferred("setup_collectibles")
	
	# Setup UI if enabled
	if show_ui:
		setup_ui()
	
	print("CollectibleManager: Initialized. Looking for ", total_collectibles, " collectibles.")

func setup_collectibles():
	# Wait for scene to be ready
	await get_tree().process_frame
	
	var collectibles = get_tree().get_nodes_in_group("collectibles")
	print("Found ", collectibles.size(), " collectibles in scene")
	
	# Connect to each collectible's signal
	for collectible in collectibles:
		if collectible.has_signal("collected") and not collectible.collected.is_connected(on_collectible_picked_up):
			collectible.collected.connect(on_collectible_picked_up.bind(collectible.collectible_name))

func on_collectible_picked_up(id: int, collectible_name: String = "Item"):
	# Prevent duplicate collection
	if id in collected_ids:
		print("WARNING: Collectible ", id, " already collected!")
		return
	
	collected_ids.append(id)
	collected_count += 1
	
	print("Collectible Manager: Picked up '", collectible_name, "' (", collected_count, "/", total_collectibles, ")")
	
	# Update UI
	update_ui()
	
	# Emit signal
	collectible_found.emit(id, collectible_name, collected_count, total_collectibles)
	
	# Check if all collected
	if collected_count >= total_collectibles:
		on_all_collectibles_found()

func on_all_collectibles_found():
	print("ALL COLLECTIBLES FOUND!")
	all_collectibles_found.emit()
	
	# Optional: Show completion screen
	if show_ui and ui_label:
		ui_label.text = "ALL " + str(total_collectibles) + " COLLECTED!\nYOU WIN!"
		ui_label.modulate = Color.GOLD
	
	# Optional: End game or trigger event
	if game_over_on_complete:
		await get_tree().create_timer(3.0).timeout
		get_tree().change_scene_to_file("res://win_screen.tscn")  # Change to your win scene

func setup_ui():
	# Create a simple UI label
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "CollectibleUI"
	add_child(canvas_layer)
	
	ui_label = Label.new()
	ui_label.name = "CollectibleLabel"
	canvas_layer.add_child(ui_label)
	
	# Style the label
	ui_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	ui_label.position = Vector2(0, 20)
	ui_label.size = Vector2(300, 100)
	ui_label.anchor_right = 1.0
	
	# Add theme/font size
	ui_label.add_theme_font_size_override("font_size", 24)
	ui_label.add_theme_color_override("font_color", Color.WHITE)
	ui_label.add_theme_color_override("font_shadow_color", Color.BLACK)
	ui_label.add_theme_constant_override("shadow_offset_x", 2)
	ui_label.add_theme_constant_override("shadow_offset_y", 2)
	
	update_ui()

func update_ui():
	if ui_label:
		ui_label.text = "Pages Collected: " + str(collected_count) + "/" + str(total_collectibles)

# Utility functions
func get_collected_count() -> int:
	return collected_count

func get_total_count() -> int:
	return total_collectibles

func is_collected(id: int) -> bool:
	return id in collected_ids

func reset_collectibles():
	collected_ids.clear()
	collected_count = 0
	update_ui()
	print("Collectibles reset")
