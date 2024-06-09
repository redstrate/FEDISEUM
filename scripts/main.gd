extends Node3D

@onready var ui: Control = $UI
@onready var player: Node3D = $Player

@onready var tag_http_request: HTTPRequest = $TagHTTPRequest
@onready var image_http_request: HTTPRequest = $ImageHTTPRequest

@onready var room_start_scene: PackedScene = preload("res://scenes/room_start.tscn")
@onready var room_a_scene: PackedScene = preload("res://scenes/room_a.tscn")
@onready var room_stairs_scene: PackedScene = preload("res://scenes/room_stairs.tscn")

var paused = false

var rooms = []
var next_link

var floor_nodes = []
var painting_nodes = []
var media_urls = {}
var media_usernames = {}
var media_dates = {}
var processed_media = {}
var current_media_url
var tag_loaded = false
var num_loaded_paintings = 0
var expected_num_paintings = 0
var entrance_node: Node3D

var last_room_x = 0.0
var last_room_y = 0.0
var last_room_rot_y = 0.0

# how many floors there are
var floors = 0

# which floor the last staircase leads to 
var floor_staircase = -1

var baseFrameMesh: Mesh

var loaded_floors: Array = []
var entrance_visible: bool = true
var entrance_faded: bool = false

enum StairDirection {
	None,
	Up,
	Down
}

var stair_direction: StairDirection = StairDirection.None

func _ready():
	if OS.has_feature('web'):
		var url = JavaScriptBridge.eval(""" 
				var url_string = window.location.href;
				var url = new URL(url_string);
				url.pathname;
			""")
		if url.length() > 1 && !url.contains(".html"):
			Global.instance_url = url.substr(1)

	# mouse capture sucks in browser?
	if !OS.has_feature("web"):	
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		
	tag_http_request.connect("request_completed", tag_request_completed, CONNECT_DEFERRED)
	image_http_request.connect("request_completed", media_request_completed, CONNECT_DEFERRED)
	
	baseFrameMesh = preload("res://models/painting.glb").instantiate().get_node("Cube").mesh
	
	# todo: use load_floor?
	loaded_floors = [0]

	var node = Node3D.new()
	node.name = "Floor " + str(0)
	add_child(node)
	
	floor_nodes.push_back(node)
	
	add_entrance()
	get_tag()
	
func _input(event):
	# capture the mouse button on first click on Web
	if OS.has_feature("web"):
		if event is InputEventMouseButton:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
func get_tag():
	tag_loaded = false
	
	print("next link: " + str(next_link))
	
	var error: Error
	if next_link != null:
		error = tag_http_request.request(next_link)
	else:
		error = tag_http_request.request("https://" + Global.instance_url + "/api/v1/timelines/tag/art?limit=30") # there's only 3 rooms max and there's 10 in each
	
	if error != OK:
		push_error("An error occurred in the HTTP request.")

func add_entrance():
	var instance = room_start_scene.instantiate()
	
	var showcase_label = instance.get_node("showcaseurl") as Label3D
	showcase_label.text = Global.instance_url + "\nSHOWCASE"
	
	var floorNode = self.floor_nodes.back()
	floorNode.add_child(instance)
	rooms.push_back(instance)
	
	entrance_node = instance
	
	last_room_x -= 6.3
	
func fade_out_fadeout(node):
	var planeMesh = node as MeshInstance3D
	var planeMat = planeMesh.get_active_material(0) as BaseMaterial3D

	var return_zoom_tween = get_tree().create_tween()
	var albedoColor = planeMat.albedo_color
	albedoColor.a = 0
	return_zoom_tween.tween_property(planeMat, "albedo_color", albedoColor, 0.2)

func add_room(target_floor):
	# fade out the entrance if this is the first room
	if !entrance_faded:
		fade_out_fadeout(entrance_node.find_child("fadeout"))
		entrance_faded = true
	
	# fade out the last room
	if !rooms.is_empty():
		fade_out_fadeout(rooms[-1].find_child("fadeout"))
	
	var instance = room_a_scene.instantiate()
	var floorNode = floor_nodes.back()
	floorNode.add_child(instance)
	rooms.push_back(instance)
		
	var instance3d = instance as Node3D
	instance3d.position.x = last_room_x
	instance3d.position.y = last_room_y
	instance3d.rotate_y(deg_to_rad(last_room_rot_y))
	
	if target_floor % 2 == 0:
		last_room_x -= 20.0
	else:
		last_room_x += 20.0
	
	painting_nodes.append_array(instance.find_children("Painting*"))

func add_stairs(target_floor: int):
	var instance: Node3D = room_stairs_scene.instantiate()
	self.add_child(instance) # stairs are intentionally not part of any floor
	rooms.push_back(instance)
	
	# todo: create common function
	instance.position.x = last_room_x
	instance.position.x = last_room_x
	instance.position.y = last_room_y
	instance.rotate_y(deg_to_rad(last_room_rot_y))
	
	var enter1_area = instance.get_node("enter1") as Area3D
	enter1_area.connect("body_entered", enter_area_entered.bind(target_floor, enter1_area.get_path()))
		
	var enter2_area = instance.get_node("enter2") as Area3D
	enter2_area.connect("body_entered", enter2_area_entered.bind(target_floor + 1, enter2_area.get_path()))
			
	var exit1_area = instance.get_node("exit1") as Area3D
	exit1_area.connect("body_entered", exit_area_entered.bind(target_floor, enter1_area.get_path()))
	
	var exit2_area = instance.get_node("exit2") as Area3D
	exit2_area.connect("body_entered", exit2_area_entered.bind(target_floor + 1, enter2_area.get_path()))
			
	last_room_rot_y += 180.0
	last_room_y += 5.8
	#last_room_x -= 0.02

# first floor enter
func enter_area_entered(body: Node3D, origin_floor, area_path: NodePath):
	self.stair_direction = StairDirection.Up
	
	# load the upper floor if not loaded already
	var target_floor = origin_floor + 1
	if not loaded_floors.has(target_floor):
		load_floor(body, target_floor, area_path)
		
	return

# first floor exit
func exit_area_entered(body: Node3D, origin_floor, area_path: NodePath):
	if self.stair_direction != StairDirection.Up:
		return
	
	# unload the next floor since we exited back onto the current floor
	var target_floor = origin_floor + 1
	if loaded_floors.has(target_floor):
		unload_floor(body, target_floor, area_path)
		
	self.stair_direction = StairDirection.None
	
	return

# second floor enter
func enter2_area_entered(body: Node3D, origin_floor, area_path: NodePath):
	self.stair_direction = StairDirection.Down
	
	# load the lower floor if not loaded already
	var target_floor = origin_floor - 1
	if not loaded_floors.has(target_floor):
		load_floor(body, target_floor, area_path)
	
	return

# second floor exit
func exit2_area_entered(body: Node3D, origin_floor, area_path: NodePath):
	if self.stair_direction != StairDirection.Down:
		return
	
	# unload the next floor since we exited back onto the current floor
	var target_floor = origin_floor - 1
	if loaded_floors.has(target_floor):
		unload_floor(body, target_floor, area_path)
		
	self.stair_direction = StairDirection.None
	
	return

func load_floor(body: Node3D, target_floor, area_path: NodePath):
	print("Loading floor: " + str(target_floor))
	loaded_floors.push_back(target_floor)
			
	if floors < target_floor:
		var node = Node3D.new()
		node.name = "Floor " + str(target_floor)
		add_child(node)
		
		floor_nodes.push_back(node)
	
		print(area_path, ": loading next floor!", floors, " to ", target_floor, " due to ", body.get_path())
		floors = target_floor
		get_tag()

func unload_floor(body: Node3D, target_floor, area_path: NodePath):
	print("Unloading floor: " + str(target_floor))
	loaded_floors.erase(target_floor)
		
func open_room_doors(instance):
	if instance == null:
		return
	
	var door_node: Node3D = instance.get_node("Doors")
	
	if door_node != null:
		var door_node_animator: AnimationPlayer = door_node.get_node("AnimationPlayer")
		door_node_animator.play("door_open")
		
func tween_door_rot(rot, door):
	var oldScale = door.scale;
	var oldPos = door.position;
	door.transform.basis = Basis()
	door.scale = oldScale
	door.position = oldPos
	door.rotate_y(deg_to_rad(rot))

enum Corner {
	TopLeft,
	TopRight,
	BottomLeft,
	BottomRight
}

func get_corner(color):
	if color.r == 0.0 && color.g == 0.0 && color.b == 0.0:
		return Corner.TopLeft
	
	if color.r > 0 && color.g == 0.0 && color.b == 0.0:
		return Corner.TopRight
		
	if color.r == 0 && color.g > 0.0 && color.b == 0.0:
		return Corner.BottomRight
		
	return Corner.BottomLeft
	
func elide_text(text):
	if text.length() >= 27:
		return text.substr(0, 26) + "..."
	else:
		return text
				
func process_next_image():
	for url in processed_media.keys():
		var media = processed_media[url]
		var texture = media["texture"]
		var piece_name = media["name"]
		var username = media["username"]
		var date = media["date"]
		#var aspect = texture.get_width() as float / texture.get_height() as float
		var aspect = texture.get_height() as float / texture.get_width() as float

		if painting_nodes.is_empty():
			print("Too many images for this room! Adding a room...")
			open_room_doors(rooms.back())
			add_room(floors)

		var node = painting_nodes.pop_front() as Node3D
		if node != null:
			#clothNode.visible = false
			
			# adding painting frame
			#var mdt = MeshDataTool.new()
			
			# todo: reimplement
			#var newMesh = baseFrameMesh.duplicate();
			#mdt.create_from_surface(newMesh, 0)
			#for i in range(mdt.get_vertex_count()):
			#	var vertex = mdt.get_vertex(i)
			#	var half_aspect = -(1.0 - aspect);
			#	match get_corner(mdt.get_vertex_color(i)):
			#		Corner.TopLeft:
			#			vertex += Vector3(-half_aspect, 0.0, 0.0)
			#		Corner.TopRight:
			#			vertex += Vector3(half_aspect, 0.0, 0.0)
			#		Corner.BottomRight:
			#			vertex += Vector3(half_aspect, -0.0, 0.0)
			#		Corner.BottomLeft:
			#			vertex += Vector3(-half_aspect, -0.0, 0.0)
			#	# Save your change.
			#	mdt.set_vertex(i, vertex)
			#newMesh.clear_surfaces()
			#mdt.commit_to_surface(newMesh)
			
			#var painting = node.get_node("frame/Cube") as MeshInstance3D
			#painting.mesh = newMesh
			
			var myMesh = node.get_node("plane2") as MeshInstance3D
			# todo: do in a later version
			if texture.get_height() > texture.get_width():
				myMesh.scale.x = 1.0 / aspect
			else:
				myMesh.scale.z = aspect
			myMesh.scale.x -= 0.1
			myMesh.scale.z -= 0.1
			var myMaterial = StandardMaterial3D.new()
			myMaterial.albedo_texture = texture
			myMesh.material_override = myMaterial
			
			var title_label = node.get_node("placard/title")
			title_label.text = elide_text(piece_name)
			var subtitle_label = node.get_node("placard/subtitle")
			subtitle_label.text = username # we don't elide usernames because that's stupid
			var date_label = node.get_node("placard/date")
			date_label.text = elide_text(date)
			
			var clothNode = node.get_node("painting_cloth") as Node3D
			var planeMesh = clothNode.get_node("Plane") as MeshInstance3D
			var planeMat = planeMesh.get_active_material(0) as BaseMaterial3D
			var newMat = planeMat.duplicate()
			
			planeMesh.set_surface_override_material(0, newMat)
			
			var return_zoom_tween = get_tree().create_tween()
			var albedoColor = newMat.albedo_color
			albedoColor.a = 0
			return_zoom_tween.tween_property(newMat, "albedo_color", albedoColor, 0.2)
		else:
			push_error("Failed to get node for ", url)
			
		processed_media.erase(url)
		num_loaded_paintings += 1
	
	if current_media_url == null && !media_urls.is_empty():
		var url = media_urls.keys()[0]
		
		current_media_url = url

		var error = image_http_request.request(url)
		if error != OK:
			push_error("An error occurred in the HTTP request.")
	
	if current_media_url == null && media_urls.is_empty() && tag_loaded && num_loaded_paintings == expected_num_paintings && floor_staircase + 1 == floors:
		print("Last room! Adding stairs...", floors, " to ", floor_staircase)
		
		open_room_doors(rooms.back())
		add_stairs(floors)
		
		floor_staircase += 1
	
func media_request_completed(_result, _response_code, headers, body):
	var image = Image.new()
	var image_error = null
	for header in headers:
		var content_type
		if header.contains("Content-Type"):
			content_type = header
		
		# web, lol
		if header.contains("content-type"):
			content_type = header
			
		if content_type != null:
			if content_type.contains("image/png"):
				image_error = image.load_png_from_buffer(body)
				
			if content_type.contains("image/jpeg"):
				image_error = image.load_jpg_from_buffer(body)
				
			if content_type.contains("image/webp"):
				image_error = image.load_webp_from_buffer(body)
	
	if image_error != OK:
		print("An error occurred while trying to display the image.", _response_code, image_error)
	else:
		var media_obj = {}
		media_obj["texture"] = ImageTexture.create_from_image(image)
		media_obj["name"] = media_urls[current_media_url]
		media_obj["username"] = media_usernames[current_media_url]
		media_obj["date"] = media_dates[current_media_url]
		processed_media[current_media_url] = media_obj
	
	media_urls.erase(current_media_url)
	media_usernames.erase(current_media_url)
	media_dates.erase(current_media_url)
	current_media_url = null

func tag_request_completed(_result, _response_code, headers, body):	
	for header in headers:
		if header.contains("Link:") or header.contains("link:"):
			var regex = RegEx.new()
			regex.compile("<(.*)>; rel=\"next\"")
			var regex_result = regex.search(header)
			if regex_result:
				next_link = regex_result.get_string(1)

	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	if response == null:
		return
	
	for post in response:
		# todo: make configurable
		if post["sensitive"] == true:
			continue
		
		var media_attachments = post["media_attachments"]
		for attachment in media_attachments:
			var preview_url = attachment["preview_url"]
			
			# strip content html
			var regex = RegEx.new()
			regex.compile("<[^>]*>")
			
			media_urls[preview_url] = regex.sub(post["content"], "", true)
			media_usernames[preview_url] = "@" + post["account"]["acct"]
			media_dates[preview_url] = post["created_at"].get_slice("-", 0)
			
			expected_num_paintings += 1
	
	tag_loaded = true
	
func update_visibility():	
	# entrance is always attached to the first floor
	entrance_visible = loaded_floors.has(0)
	
	var i = 0
	for floor_node in floor_nodes:
		if loaded_floors.has(i):
			floor_node.visible = true
		else:
			floor_node.visible = false
			
		i += 1
		
	entrance_node.visible = entrance_visible

func _process(_delta):
	process_next_image()
	
	ui.update_loaded_paintings(num_loaded_paintings)
	ui.update_loaded_floors(str(loaded_floors))
	ui.update_entrance_visible(entrance_visible)
	
	update_visibility()
	
	if !OS.has_feature("web"):
		if Input.is_action_just_pressed("pause"):
			paused = !paused
			
			if paused:
				ui.show_pause_menu()
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				ui.hide_pause_menu()
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			
			get_tree().paused = paused
