extends CharacterBody3D

var camera: Camera3D
var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var zoom_tween: Tween
var return_zoom_tween: Tween

func _ready():
	camera = $Camera3D

func kill_existing_tweens():
	if zoom_tween:
		zoom_tween.kill()
		
	if return_zoom_tween:
		return_zoom_tween.kill()
	
func begin_zoom():
	kill_existing_tweens()
		
	zoom_tween = get_tree().create_tween()
	zoom_tween.tween_property($Camera3D, "fov", 40.0, 0.4)

func end_zoom():
	kill_existing_tweens()
	
	return_zoom_tween = get_tree().create_tween()
	return_zoom_tween.tween_property($Camera3D, "fov", 75.0, 0.15)

func _physics_process(delta):
	if Input.is_action_just_pressed("zoom"):
		begin_zoom()
	else:
		if Input.is_action_just_released("zoom"):
			end_zoom()

	var dir = Vector3()
	var cam_xform = camera.get_global_transform()

	var input_movement_vector = Vector2.ZERO

	if Input.is_action_pressed("movement_forward"):
		input_movement_vector.y += 1
	if Input.is_action_pressed("movement_backward"):
		input_movement_vector.y -= 1
	if Input.is_action_pressed("movement_left"):
		input_movement_vector.x -= 1
	if Input.is_action_pressed("movement_right"):
		input_movement_vector.x += 1
		
	input_movement_vector = input_movement_vector.normalized()
			
	dir += -cam_xform.basis.z * input_movement_vector.y * 1.5
	dir += cam_xform.basis.x * input_movement_vector.x * 1.5
	dir.y = -gravity * delta
	self.velocity = dir * 2.5
	
	self.move_and_slide()

func _input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		camera.rotation.x += -event.relative.y * 0.005
		camera.rotation.y += -event.relative.x * 0.005

		var camera_rot = camera.rotation_degrees
		camera_rot.x = clamp(camera_rot.x, -70, 70)
		camera.rotation_degrees = camera_rot
