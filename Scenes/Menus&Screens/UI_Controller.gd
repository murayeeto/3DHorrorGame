extends CanvasLayer

# References to the heart TextureRects (assign these in the editor)
@export var heart1: TextureRect
@export var heart2: TextureRect
@export var heart3: TextureRect

# Store hearts in an array for easy access
var hearts: Array[TextureRect] = []
var player: CharacterBody3D = null

func _ready():
	# Build hearts array
	if heart1:
		hearts.append(heart1)
	if heart2:
		hearts.append(heart2)
	if heart3:
		hearts.append(heart3)
	
	# Find the player
	await get_tree().process_frame
	player = get_tree().get_first_node_in_group("player")
	
	if player:
		print("UI connected to player")
		# Connect to player's health changes
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
	else:
		print("WARNING: UI could not find player!")
	
	# Initial update
	update_hearts(3)

# Update the hearts display based on current health
func update_hearts(current_health: int):
	print("Updating hearts display: ", current_health)
	
	# Show/hide hearts based on health
	for i in range(hearts.size()):
		if hearts[i]:
			# Show heart if health is greater than index
			hearts[i].visible = (i < current_health)

# Called when player's health changes
func _on_player_health_changed(new_health: int):
	update_hearts(new_health)
