extends RefCounted
## Builds the soldier figure used in menus (and later in matches).
##
## If a .glb/.gltf model has been placed under assets/models/characters/<pack>/ it is used
## (a file with "soldier" in its name is preferred). It is scaled to 1.8 m, its feet are put
## on the floor, and an animation named like "idle" is looped if the model has one.
## Without a model, a simple low-poly placeholder soldier is built from primitive shapes.
##
## Soldiers face +Z (towards a camera placed on the positive Z axis).

const C = preload("res://game/autoload/config.gd")

const MODEL_DIR := "res://assets/models/characters"
const MODEL_EXTENSIONS: PackedStringArray = ["glb", "gltf"]
const TARGET_HEIGHT := 1.8

const UNIFORM_COLORS := [Color(0.27, 0.31, 0.24), Color(0.22, 0.25, 0.29), Color(0.40, 0.36, 0.27)]
const GEAR_COLORS := [Color(0.15, 0.17, 0.14), Color(0.12, 0.14, 0.16), Color(0.23, 0.21, 0.16)]
const SKIN_COLOR := Color(0.72, 0.55, 0.43)
const BOOT_COLOR := Color(0.09, 0.10, 0.10)
const METAL_COLOR := Color(0.12, 0.13, 0.14)

static var _materials: Dictionary = {}


## variant 0, 1 or 2 changes the uniform colour of the placeholder soldier.
static func create_soldier(variant: int = 0) -> Node3D:
	var root := Node3D.new()
	root.name = "Soldier"
	var model := _load_model()
	if model != null:
		_attach_model(root, model)
	else:
		_build_placeholder(root, variant)
	return root


## Starts the idle animation. The soldier must already be inside the scene tree.
static func start_idle(soldier: Node3D) -> void:
	if soldier.has_meta("anim_player"):
		var player := soldier.get_meta("anim_player") as AnimationPlayer
		var anim_name := StringName(soldier.get_meta("idle_name"))
		if is_instance_valid(player) and player.has_animation(anim_name):
			player.get_animation(anim_name).loop_mode = Animation.LOOP_LINEAR
			player.play(anim_name)
			return
	_procedural_idle(soldier)


# ---- Loaded models --------------------------------------------------------------------------

static func _load_model() -> Node3D:
	var path := C.find_asset(MODEL_DIR, MODEL_EXTENSIONS, "soldier")
	if path == "":
		return null
	var scene := C.load_optional(path) as PackedScene
	if scene == null:
		return null
	return scene.instantiate() as Node3D


static func _attach_model(root: Node3D, model: Node3D) -> void:
	var bounds := {}
	_gather_bounds(model, Transform3D.IDENTITY, bounds)
	var pivot := Node3D.new()
	pivot.name = "Pivot"
	root.add_child(pivot)
	pivot.add_child(model)
	if bounds.has("box"):
		var box: AABB = bounds["box"]
		if box.size.y > 0.01:
			var factor := TARGET_HEIGHT / box.size.y
			var center := box.get_center()
			pivot.scale = Vector3.ONE * factor
			pivot.position = Vector3(-center.x * factor, -box.position.y * factor, -center.z * factor)
	root.set_meta("body", pivot)
	for node in model.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		for anim_name in player.get_animation_list():
			if String(anim_name).to_lower().contains("idle"):
				root.set_meta("anim_player", player)
				root.set_meta("idle_name", String(anim_name))
				return


static func _gather_bounds(node: Node, parent_xform: Transform3D, out: Dictionary) -> void:
	var xform := parent_xform
	if node is Node3D:
		xform = parent_xform * (node as Node3D).transform
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		if instance.mesh != null:
			var box: AABB = xform * instance.mesh.get_aabb()
			if out.has("box"):
				box = (out["box"] as AABB).merge(box)
			out["box"] = box
	for child in node.get_children():
		_gather_bounds(child, xform, out)


# ---- Placeholder soldier ------------------------------------------------------------------

static func _build_placeholder(root: Node3D, variant: int) -> void:
	var index := posmod(variant, UNIFORM_COLORS.size())
	var uniform: Color = UNIFORM_COLORS[index]
	var gear: Color = GEAR_COLORS[index]

	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	root.set_meta("body", body)

	for side in [-1.0, 1.0]:
		var x := 0.11 * float(side)
		_box(body, Vector3(0.17, 0.78, 0.20), uniform, Vector3(x, 0.51, 0.0))
		_box(body, Vector3(0.18, 0.12, 0.30), BOOT_COLOR, Vector3(x, 0.06, 0.04))

	_box(body, Vector3(0.40, 0.14, 0.24), uniform, Vector3(0.0, 0.93, 0.0))
	_box(body, Vector3(0.44, 0.56, 0.25), uniform, Vector3(0.0, 1.20, 0.0))
	_box(body, Vector3(0.48, 0.42, 0.30), gear, Vector3(0.0, 1.24, 0.0))

	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.58, 0.0)
	body.add_child(head)
	_sphere(head, 0.11, SKIN_COLOR, Vector3(0.0, 0.05, 0.0))
	_sphere(head, 0.135, gear, Vector3(0.0, 0.10, 0.0), Vector3(1.0, 0.85, 1.05))

	var arm_r := _arm(body, Vector3(0.28, 1.43, 0.0), uniform, Vector3(-62.0, 0.0, -10.0))
	var arm_l := _arm(body, Vector3(-0.28, 1.43, 0.0), uniform, Vector3(-50.0, 0.0, 20.0))

	_box(body, Vector3(0.06, 0.10, 0.78), METAL_COLOR, Vector3(0.04, 1.17, 0.34))
	_box(body, Vector3(0.05, 0.16, 0.06), METAL_COLOR, Vector3(0.04, 1.06, 0.30))

	root.set_meta("head", head)
	root.set_meta("arm_r", arm_r)
	root.set_meta("arm_l", arm_l)


static func _arm(parent: Node3D, shoulder: Vector3, color: Color, rotation_deg: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = shoulder
	pivot.rotation_degrees = rotation_deg
	parent.add_child(pivot)
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.06
	mesh.height = 0.58
	mesh.radial_segments = 12
	mesh.rings = 4
	mesh.material = _material(color)
	var arm := MeshInstance3D.new()
	arm.mesh = mesh
	arm.position = Vector3(0.0, -0.27, 0.0)
	pivot.add_child(arm)
	_sphere(pivot, 0.055, SKIN_COLOR, Vector3(0.0, -0.57, 0.0))
	return pivot


static func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html()
	if not _materials.has(key):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 0.9
		_materials[key] = material
	return _materials[key] as StandardMaterial3D


static func _box(parent: Node3D, box_size: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	mesh.material = _material(color)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	parent.add_child(node)
	return node


static func _sphere(parent: Node3D, radius: float, color: Color, pos: Vector3,
		scale_xyz: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.material = _material(color)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = pos
	node.scale = scale_xyz
	parent.add_child(node)
	return node


# ---- Idle animation without an animation file ----------------------------------------------

static func _procedural_idle(soldier: Node3D) -> void:
	var speed := randf_range(0.9, 1.1)

	if soldier.has_meta("body"):
		var body := soldier.get_meta("body") as Node3D
		var base_y := body.position.y
		var bob := soldier.create_tween().set_loops()
		bob.set_speed_scale(speed)
		bob.set_trans(Tween.TRANS_SINE)
		bob.set_ease(Tween.EASE_IN_OUT)
		bob.tween_property(body, "position:y", base_y + 0.014, 1.2)
		bob.tween_property(body, "position:y", base_y, 1.2)

	if soldier.has_meta("head"):
		var head := soldier.get_meta("head") as Node3D
		var look := soldier.create_tween().set_loops()
		look.set_speed_scale(speed)
		look.set_trans(Tween.TRANS_SINE)
		look.set_ease(Tween.EASE_IN_OUT)
		look.tween_property(head, "rotation_degrees:y", 7.0, 2.4)
		look.tween_property(head, "rotation_degrees:y", -7.0, 4.8)

	for key in ["arm_r", "arm_l"]:
		if soldier.has_meta(key):
			var arm := soldier.get_meta(key) as Node3D
			var base_x := arm.rotation_degrees.x
			var sway := soldier.create_tween().set_loops()
			sway.set_speed_scale(speed)
			sway.set_trans(Tween.TRANS_SINE)
			sway.set_ease(Tween.EASE_IN_OUT)
			sway.tween_property(arm, "rotation_degrees:x", base_x + 2.0, 1.2)
			sway.tween_property(arm, "rotation_degrees:x", base_x, 1.2)