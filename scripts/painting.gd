extends Node3D

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

# Called when the node enters the scene tree for the first time.
func _ready():
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, BoxMesh.new().get_mesh_arrays())
	var mdt = MeshDataTool.new()
	
	var painting = get_node("painting/Cube") as MeshInstance3D
	
	mdt.create_from_surface(painting.mesh, 0)
	for i in range(mdt.get_vertex_count()):
		var vertex = mdt.get_vertex(i)
		# In this example we extend the mesh by one unit, which results in separated faces as it is flat shaded.
		print(mdt.get_vertex_color(i))
		
		match get_corner(mdt.get_vertex_color(i)):
			Corner.TopLeft:
				vertex += Vector3(-1, 1.0, 0.0)
			Corner.TopRight:
				vertex += Vector3(1, 1.0, 0.0)
			Corner.BottomRight:
				vertex += Vector3(1, -1.0, 0.0)
			Corner.BottomLeft:
				vertex += Vector3(-1, -1.0, 0.0)
		# Save your change.
		mdt.set_vertex(i, vertex)
	mesh.clear_surfaces()
	mdt.commit_to_surface(mesh)
	var mi = MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)

	
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
