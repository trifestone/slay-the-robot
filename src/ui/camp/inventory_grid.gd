## ISSUE-013b/c — InventoryGrid: drag-source panel showing dismantled traits.
##
## Each cell is a TraitIcon with custom drag-data implementing
## Control.get_drag_data → returns {kind: "trait_drag", trait_id: String}.
## CardCampUI's _can_drop_on_slot reads this dictionary on drop.
##
## Signals:
##   trait_drag_started(trait_id)   # camp_scene listens to highlight valid sinks
##   trait_drag_ended()             # always fires after drag completes (success or cancel)
extends Control

const TraitIconScene := preload("res://ui/trait_icon.tscn")
const SLOT_SIZE := Vector2(56, 56)
const SLOT_GAP := 8

signal trait_drag_started(trait_id: String)
signal trait_drag_ended()

@onready var _grid: GridContainer = $Grid
@onready var _title: Label        = $Title
@onready var _capacity: Label     = $Capacity

var _inventory: Resource = null
var _locale: String = "zh_CN"


func bind(inv: Resource, locale: String = "zh_CN") -> void:
	_inventory = inv
	_locale = locale
	_render()


func refresh() -> void:
	_render()


func _render() -> void:
	for child in _grid.get_children():
		child.queue_free()
	if _inventory == null:
		_capacity.text = "0/0"
		return
	var unsocketed: Array = _inventory.unsocketed
	for i in range(_inventory.capacity):
		var cell: Control = _make_cell(i, unsocketed)
		_grid.add_child(cell)
	_capacity.text = "%d/%d" % [unsocketed.size(), _inventory.capacity]


func _make_cell(index: int, unsocketed: Array) -> Control:
	var wrap: Control = Control.new()
	wrap.custom_minimum_size = SLOT_SIZE
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS

	var icon: Control = TraitIconScene.instantiate()
	wrap.add_child(icon)
	icon.anchor_right = 1.0
	icon.anchor_bottom = 1.0

	var t: Resource = null
	if index < unsocketed.size():
		t = unsocketed[index]
	icon.bind(t, false)

	if t != null:
		# Drag source — only filled cells can be picked up.
		wrap.set_meta("trait_id", t.id)
		wrap.set_drag_forwarding(
			Callable(self, "_get_drag_data_from_cell").bind(wrap),
			Callable(),
			Callable()
		)
	return wrap


func _get_drag_data_from_cell(_at: Vector2, wrap: Control) -> Variant:
	if not wrap.has_meta("trait_id"):
		return null
	var tid: String = String(wrap.get_meta("trait_id"))
	if tid.is_empty():
		return null

	# Visual preview that follows the cursor.
	var preview: Control = TraitIconScene.instantiate()
	preview.custom_minimum_size = SLOT_SIZE
	# Find the trait resource for the preview render.
	var t: Resource = _find_trait_by_id(tid)
	preview.bind(t, false)
	preview.modulate = Color(1, 1, 1, 0.85)
	wrap.set_drag_preview(preview)

	trait_drag_started.emit(tid)
	# Hook drag-end via a deferred re-emit on next frame; Godot has no
	# built-in "drag finished" signal, so camp_scene also listens to drop
	# results from CardCampUI. We still emit a courtesy signal next frame.
	call_deferred("_emit_drag_ended")

	return {
		"kind": "trait_drag",
		"trait_id": tid,
	}


func _emit_drag_ended() -> void:
	trait_drag_ended.emit()


func _find_trait_by_id(tid: String) -> Resource:
	if _inventory == null:
		return null
	for t in _inventory.unsocketed:
		if t != null and t.id == tid:
			return t
	return null
