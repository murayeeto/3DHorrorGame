# PauseMenu.gd
extends Control

var is_paused = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	
	# Connect buttons
	var resume_btn = get_node_or_null("ResumeButton")
	var quit_btn = get_node_or_null("QuitButton")
	
	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
	
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_to_menu_pressed)

func _input(event):
	if event.is_action_pressed("ui_cancel"):
		toggle_pause()
		get_viewport().set_input_as_handled()

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused
	visible = is_paused
	
	if is_paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed():
	toggle_pause()

func _on_quit_to_menu_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Menus&Screens/TitleScreen.tscn")
