extends CanvasLayer

# References to the heart TextureRects (assign these in the editor)
@export var heart1: TextureRect
@export var heart2: TextureRect
@export var heart3: TextureRect
@export var item_counter_label: Label

# Store hearts in an array for easy access
var hearts: Array[TextureRect] = []
var player: CharacterBody3D = null
var current_items: int = 0
var max_items: int = 8

func _ready():
	# Build hearts array
	if heart1:
		hearts.append(heart1)
	if heart2:
		hearts.append(heart2)
	if heart3:
		hearts.append(heart3)
	
	print("UI: Hearts array size: ", hearts.size())
	
	# Find the player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		print("UI: Connected to player")
		# Connect to player's health changes
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
			print("UI: Successfully connected to health_changed signal")
		else:
			print("ERROR: Player doesn't have health_changed signal!")
	else:
		print("WARNING: UI could not find player!")
	
	# Initial update
	update_hearts(3)
	update_item_counter()

# Update the hearts display based on current health
func update_hearts(current_health: int):
	print("Updating hearts display: ", current_health)
	
	# Show/hide hearts based on health
	for i in range(hearts.size()):
		if hearts[i]:
			# Show heart if health is greater than index
			hearts[i].visible = (i < current_health)

# Update the item counter display
func update_item_counter():
	if item_counter_label:
		item_counter_label.text = "%d/%d" % [current_items, max_items]

# Call this from player.gd when an item is picked up
func add_item():
	current_items = min(current_items + 1, max_items)
	update_item_counter()

# Called when player's health changes
func _on_player_health_changed(new_health: int):
	print("UI: Received health changed signal! New health: ", new_health)
	update_hearts(new_health)
