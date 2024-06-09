extends Node

@onready var fade: ColorRect = $Control/fade
@onready var tip: Control = $Control/tip
@onready var version: Label = $Control/Label3
@onready var play_timer: Timer = $Timer
@onready var line_edit: LineEdit = $Control/LineEdit

func _ready():
	fade.visible = true
	version.text = "Version " + ProjectSettings.get_setting("application/config/version")
	line_edit.text = Global.instance_url
	pass

func _on_fadetimer_timeout():
	var zoom_tween = get_tree().create_tween()
	var color = fade.color
	color.a = 0.0
	zoom_tween.tween_property(fade, "color", color, 0.2)

func play():
	var zoom_tween = get_tree().create_tween()
	var color = fade.color
	color.a = 1.0
	zoom_tween.tween_property(fade, "color", color, 0.4)
	
	var mod_tween = get_tree().create_tween()
	var tcolor = tip.modulate
	tcolor.a = 1.0
	mod_tween.tween_property(tip, "modulate", tcolor, 0.4)
	
	play_timer.start()

func _on_play_timer_timeout():
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_button_button_down():
	Global.instance_url = line_edit.text
	play()
