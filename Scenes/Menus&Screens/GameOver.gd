# GameOver.gd - MINIMAL VERSION
extends Control

func _ready():
	print("GameOver started")
	process_mode = PROCESS_MODE_ALWAYS
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
	# Connect buttons
	var restart_btn = $RestartButton
	var quit_btn = $QuitButton
	
	if restart_btn:
		restart_btn.pressed.connect(restart_game)
		print("Restart connected")
	if quit_btn:
		quit_btn.pressed.connect(quit_to_menu)
		print("Quit connected")

func restart_game():
	print("Restarting game...")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Levels/school_map.tscn")
   
func quit_to_menu():
	print("Going to menu...")
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Menus&Screens/TitleScreen.tscn")
