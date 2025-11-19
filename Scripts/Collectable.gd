extends Area3D
class_name Collectible

# Emitted when this collectible is picked up
signal collected(collectible_id: int)

# Export variables
@export var collectible_id: int = 1  # Unique ID for this collectible
@export var collectible_name: String = "Page"  # Display name
@export var rotation_speed: float = 30.0  # Degrees per second
@export var bob_height: float = 0.2  # How much it bobs up/down
@export var bob_speed: float = 2.0  # How fast it bobs
@export var glow_enabled: bool = true  # Add glow effect
@export var pickup_sound: AudioStream = null  # Optional pickup sound

# Internal variables
var initial_position: Vector3
var time_passed: float = 0.0
var is_collected: bool = false
var player_nearby: bool = false

# Child nodes
@onready var visual_node: Node3D = get_node_or_null("Visual")  # Your 3D model goes here
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()

func _ready():
	# Store initial position for bobbing animation
	initial_position = global_position
	
	# Setup audio player
	add_child(audio_player)
	if pickup_sound:
		audio_player.stream = pickup_sound
	
	# Connect to body entered signal (for player detection)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	# Add to "collectibles" group for easy finding
	add_to_group("collectibles")
	
	# Setup collision layers
	collision_layer = 4  # Layer 3 (bit 2)
	collision_mask = 0   # Doesn't detect anything, only gets detected
	
	print("Collectible ", collectible_id, " (", collectible_name, ") ready at: ", global_position)

func _physics_process(delta):
	if is_collected:
		return
	
	time_passed += delta
	
	# Rotating animation
	if visual_node:
		visual_node.rotation.y += deg_to_rad(rotation_speed) * delta
	else:
		# Rotate self if no visual child
		rotation.y += deg_to_rad(rotation_speed) * delta
	
	# Bobbing animation
	var bob_offset = sin(time_passed * bob_speed) * bob_height
	global_position.y = initial_position.y + bob_offset
	
	# Glow effect (pulsing scale)
	if glow_enabled and visual_node:
		var pulse = 1.0 + sin(time_passed * 3.0) * 0.1
		visual_node.scale = Vector3.ONE * pulse

func _on_body_entered(body: Node3D):
	if is_collected:
		return
	
	# Check if it's the player
	if body.is_in_group("player") or body is CharacterBody3D:
		player_nearby = true
		collect()

func _on_body_exited(body: Node3D):
	if body.is_in_group("player") or body is CharacterBody3D:
		player_nearby = false

func collect():
	if is_collected:
		return
	
	is_collected = true
	print("Collected: ", collectible_name, " (ID: ", collectible_id, ")")
	
	# Play sound
	if pickup_sound and audio_player:
		audio_player.play()
	
	# Emit signal to manager
	collected.emit(collectible_id)
	
	# Notify CollectibleManager
	var manager = get_tree().get_first_node_in_group("collectible_manager")
	if manager and manager.has_method("on_collectible_picked_up"):
		manager.on_collectible_picked_up(collectible_id, collectible_name)
	
	# Disappear with animation
	disappear()

func disappear():
	# Disable collision
	collision_shape.disabled = true
	
	# Fade out animation
	var tween = create_tween()
	tween.set_parallel(true)
	
	if visual_node:
		tween.tween_property(visual_node, "scale", Vector3.ZERO, 0.3)
		tween.tween_property(visual_node, "position:y", visual_node.position.y + 2.0, 0.3)
	else:
		tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
		tween.tween_property(self, "position:y", position.y + 2.0, 0.3)
	
	# Wait for animation, then remove
	await tween.finished
	
	# Wait for sound to finish if playing
	if audio_player.playing:
		await audio_player.finished
	
	queue_free()

# Optional: Show prompt when player is nearby
func show_pickup_prompt():
	# You can implement UI prompt here
	# Example: "Press E to collect"
	pass
