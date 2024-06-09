extends Node

@onready var pause_menu: Control = $Pause
@onready var loaded_paintings: Label = $Debug/LoadedPaintings
@onready var loaded_floors: Label = $Debug/LoadedFloors
@onready var entrance_visible: Label = $Debug/EntranceVisible
@onready var fps: Label = $Debug/FPS
@onready var debug_ui: Control = $Debug
@onready var fade: ColorRect = $fade

func _ready():
	fade.visible = true
	
	var zoom_tween = get_tree().create_tween()
	var color = fade.color
	color.a = 0.0
	zoom_tween.tween_property(fade, "color", color, 0.6)

	hide_pause_menu()
	
	#debug_ui.visible = OS.is_debug_build()

func show_pause_menu():
	pause_menu.visible = true

func hide_pause_menu():
	pause_menu.visible = false

func update_loaded_paintings(num_paintings):
	loaded_paintings.text = "(Lifetime) Loaded Paintings: " + str(num_paintings)

func update_loaded_floors(floors):
	loaded_floors.text = "Current Loaded floors: " + floors

func update_entrance_visible(is_visible):
	entrance_visible.text = "Entrance Visible: " + str(is_visible)

func _process(_delta):
	fps.text = "FPS:" + str(Engine.get_frames_per_second())
