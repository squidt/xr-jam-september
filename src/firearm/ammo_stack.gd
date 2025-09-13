@tool
extends Path3D

## Places ammo along a path [br]
## Can be used to create either bullets in a magazine or ammo box

@export_tool_button("Refresh") var refresh = place_instances
@export var refresh_on_change: bool = true
@export var scene: PackedScene
@export var rotation_local: Vector3:
	set(v):
		rotation_local = v
		place_instances()

@export var stack_size: int = 1:
	set(v):
		stack_size = v
		place_instances()

@export var columns: int = 2:
	set(v):
		columns = v
		place_instances()

@export var start_offset = .01:
	set(v):
		start_offset = v
		place_instances()

## Width between each cartridge
@export_range(0.0, 0.5, 0.0001) var width_between = .01:
	set(v):
		width_between = v
		place_instances()

## Height Between each cartridge
@export_range(0.0, 0.5, 0.0001) var height_between = .01:
	set(v):
		height_between = v
		place_instances()

## Offsets columns vertically
@export_range(0.0, 0.5, 0.0001) var column_offset = .01:
	set(v):
		column_offset = v
		place_instances()

@export var single_feed_count: int = 0:
	set(v):
		single_feed_count = v
		place_instances()

@export_range(0.0, 0.5, 0.0001) var single_feed_offset: float = 0.01:
	set(v):
		single_feed_offset = v
		place_instances()

@export_range(-0.01, 0.01, 0.0001) var single_feed_after_offset: float = 0.01:
	set(v):
		single_feed_after_offset = v
		place_instances()


func _ready() -> void:
	curve_changed.connect(place_instances)


func clear_instances() -> void:
	for c in get_children():
		if c.is_in_group("AmmoStackChildInternal"):
			c.queue_free()


func place_instances() -> void:
	clear_instances()

	if !scene or !scene.can_instantiate():
		return

	for i in range(stack_size):
		var is_single_feed = i < single_feed_count
		var effective_index = i if is_single_feed else i - single_feed_count
		var effective_columns = 1 if is_single_feed else columns

		@warning_ignore("integer_division")
		var row = effective_index / effective_columns
		var col = 0 if is_single_feed else effective_index % columns

		var row_add = row * (single_feed_offset if is_single_feed else height_between)
		var col_add = 0.0 if is_single_feed else col * (height_between / 2.0)
		var offset = start_offset + row_add + col_add

		# Offset the double-stack section to come after the single-fed rounds (with between the two)
		if not is_single_feed:
			offset += single_feed_count * single_feed_offset + single_feed_after_offset

		var sampled = curve.sample_baked_with_rotation(offset, true, true)

		var sideways = 0.0
		if not is_single_feed:
			var x_center_offset = ((columns - 1) * width_between) / 2.0
			sideways = col * width_between - x_center_offset

		sampled = sampled.translated_local(Vector3(sideways, 0, 0))

		var instance = scene.instantiate()
		instance.global_transform = sampled

		# Apply user-defined additional rotation
		instance.rotate_object_local(Vector3.RIGHT, deg_to_rad(rotation_local.x))
		instance.rotate_object_local(Vector3.UP, deg_to_rad(rotation_local.y))
		instance.rotate_object_local(Vector3.BACK, deg_to_rad(rotation_local.z))

		instance.add_to_group("AmmoStackChildInternal")
		add_child(instance)
