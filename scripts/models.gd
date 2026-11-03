@tool
class_name Models
## Loads model files once and hands out merged meshes for cheap rendering.

static var _merged := {}


static func merged(path: String) -> ArrayMesh:
	if _merged.has(path):
		return _merged[path]
	var root: Node3D = (load(path) as PackedScene).instantiate()
	var st := SurfaceTool.new()
	var material: Material = null
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var item: Array = stack.pop_back()
		var node: Node = item[0]
		var xf: Transform3D = item[1]
		if node is Node3D and node != root:
			xf = xf * (node as Node3D).transform
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var m: Mesh = (node as MeshInstance3D).mesh
			for s in m.get_surface_count():
				st.append_from(m, s, xf)
				if material == null:
					material = m.surface_get_material(s)
		for c in node.get_children():
			stack.append([c, xf])
	var mesh := st.commit()
	if material:
		mesh.surface_set_material(0, material)
	root.free()
	_merged[path] = mesh
	return mesh


## Builds a MultiMesh node from a list of transforms.
static func scatter(mesh: Mesh, xforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = mm
	return node
