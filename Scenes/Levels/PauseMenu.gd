# PauseMenu.gd - Attach this to a Control node in your school_map scene
extends Control

var is_paused = false

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	visible = false  # Hide until player pauses
	
	# Connect buttons
	var resume_btn = $ResumeButton
	var quit_btn = $QuitButton
	
	if resume_btn:
		resume_btn.pressed.connect(_on_resume_pressed)
		print("Resume button connected")
	if quit_btn:
		quit_btn.pressed.connect(_on_quit_to_menu_pressed)
		print("Quit button connected")

func _process(delta):
	# Press ESC to toggle pause
	if Input.is_action_just_pressed("ui_cancel"):
		toggle_pause()

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused
	visible = is_paused
	
	if is_paused:
		print("Game paused")
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		print("Game resumed")
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed():
	print("Resume pressed")
	toggle_pause()

func _on_quit_to_menu_pressed():
	print("Quit pressed")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Menus&Screens/TitleScreen.tscn")
