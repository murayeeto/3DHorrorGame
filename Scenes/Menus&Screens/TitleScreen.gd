# TitleScreen.gd - Save this as a new GDScript file
extends Node3D

@onready var camera = $Camera3D
@onready var title_label = $CanvasLayer/Control/TitleLabel
var rotation_speed = 0.3
var camera_distance = 4
var camera_height = 6

func _ready():
	# Make sure we're showing the title screen
	get_tree().paused = false
	
	if camera == null:
		push_error("Camera3D not found! Make sure you have a Camera3D node in TitleScreen.")
	
	# Setup title text
	if title_label:
		title_label.text = "SCHOOL OF HORRORS"
		title_label.add_theme_font_size_override("font_size", 60)

func _process(delta):
	# Orbit the camera around the center of the map
	var angle = get_tree().get_frame() * rotation_speed * delta
	camera.global_position = Vector3(
		sin(angle) * camera_distance,
		camera_height,
		cos(angle) * camera_distance
	)
	# Make camera look at center of map
	camera.look_at(Vector3(0, camera_height, 0), Vector3.UP)
	
	# TEST: Press Spacebar/Enter to remove all hearts and trigger game over
	if Input.is_action_just_pressed("ui_accept"):
		trigger_game_over()

func trigger_game_over():
	# Find the player and remove all hearts
	var player = get_tree().get_nodes_in_group("player")[0] if get_tree().get_nodes_in_group("player").size() > 0 else null
	if player == null:
		# Try to find player by name
		player = get_tree().root.find_child("Player", true, false)
	
	if player and player.has_method("take_damage"):
		# Remove all hearts at once
		player.hearts = 0
		player.take_damage(999)  # Deal massive damage to trigger game over
	else:
		# Fallback: just go to game over screen
		get_tree().paused = false
		get_tree().change_scene_to_file("res://Scenes/Menus&Screens/GameOver.tscn")

func _on_play_button_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Levels/school_map(BASE).tscn")
