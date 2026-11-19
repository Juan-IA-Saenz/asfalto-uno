extends RefCounted

const PAVEMENT = preload("res://art/pavement.gdshader")
static var boxes := BoxMesh.new()
static var spheres := SphereMesh.new()
static var materials: Dictionary = {}

static func material(value: Variant, rough := 0.85, metal := 0.0, emission := 0.0) -> Material:
	if value is Material:
		return value
	var color: Color = value if value is Color else Color(value)
	var key := [color, rough, metal, emission]
	if materials.has(key):
		return materials[key]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	mat.metallic = metal
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	materials[key] = mat
	return mat

static func surface(color: Color, grain: float, cracks: float, density := 150.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PAVEMENT
	mat.set_shader_parameter("tint", color)
	mat.set_shader_parameter("grain", grain)
	mat.set_shader_parameter("crack", cracks)
	mat.set_shader_parameter("scale", density)
	return mat

static func pivot(parent: Node3D, p: Vector3) -> Node3D:
	var node := Node3D.new()
	parent.add_child(node)
	node.position = p
	return node

static func mesh(parent: Node3D, geo: Mesh, p: Vector3, size: Vector3, value: Variant, shadows := true) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	parent.add_child(node)
	node.mesh = geo
	node.position = p
	node.scale = size
	node.material_override = material(value)
	if not shadows:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node

static func box(parent: Node3D, p: Vector3, size: Vector3, value: Variant, shadows := true) -> MeshInstance3D:
	return mesh(parent, boxes, p, size, value, shadows)

static func oval(parent: Node3D, p: Vector3, size: Vector3, value: Variant, shadows := true) -> MeshInstance3D:
	spheres.radial_segments = 24
	spheres.rings = 12
	return mesh(parent, spheres, p, size, value, shadows)

static func pipe(parent: Node3D, a: Vector3, b: Vector3, r1: float, value: Variant, r2 := -1.0, sides := 10, shadows := true) -> MeshInstance3D:
	var geo := CylinderMesh.new()
	geo.radial_segments = sides
	geo.rings = 1
	geo.bottom_radius = r1
	geo.top_radius = r1 if r2 < 0 else r2
	geo.height = a.distance_to(b)
	var node := mesh(parent, geo, (a+b)*0.5, Vector3.ONE, value, shadows)
	node.quaternion = Quaternion(Vector3.UP, (b-a).normalized())
	return node

static func torus(parent: Node3D, p: Vector3, diameter: float, thickness: float, value: Variant) -> MeshInstance3D:
	var geo := TorusMesh.new()
	geo.rings = 48
	geo.ring_segments = 10
	geo.inner_radius = diameter*0.5 - thickness*0.5
	geo.outer_radius = diameter*0.5 + thickness*0.5
	return mesh(parent, geo, p, Vector3.ONE, value)

static func words(parent: Node3D, p: Vector3, caption: String, size: float, ink: Color) -> Label3D:
	var node := Label3D.new()
	parent.add_child(node)
	node.position = p
	node.text = caption
	node.font = preload("res://art/BarlowCondensed-ExtraBoldItalic.ttf")
	node.font_size = 110
	node.pixel_size = size / 110.0
	node.modulate = ink
	node.outline_size = 0
	node.double_sided = false
	return node

static func batch_boxes(parent: Node3D, transforms: Array[Transform3D], mat: Variant) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = boxes
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var n := MultiMeshInstance3D.new()
	n.multimesh = mm
	n.material_override = material(mat)
	n.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(n)

static func xf(p: Vector3, s: Vector3, r := 0.0) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, r).scaled(s) if is_zero_approx(r) else Basis(Vector3.UP, r) * Basis.from_scale(s), p)
