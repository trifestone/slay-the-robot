## ISSUE-013b — Camp variant of CardUI: a single TraitCard rendered with
## drop-receiving slots and a per-card "Reforge" button.
##
## Differences from ui/card_ui.gd (battle hand variant):
##   - Each slot is a separate Control that accepts drag-drop via
##     `_can_drop_data` / `_drop_data` (ISSUE-013c).
##   - Right-click on a non-base slot dismantles (emits `dismantle_requested`).
##   - Reforge button at top-right emits `reforge_requested`.
##   - Hover on any slot emits `slot_hovered(card, slot_idx, candidate_trait)`
##     so reaction_preview.gd (ISSUE-014b) can render the diff tooltip.
##
## Signals:
##   mount_requested(card, slot_idx, trait_id)
##   dismantle_requested(card, slot_idx)
##   reforge_requested(card)
##   slot_hovered(card, slot_idx, candidate_trait_id)   # candidate may be ""
##   slot_unhovered(card, slot_idx)
extends Control

const TraitIconScene := preload("res://ui/trait_icon.tscn")
const ResolverScript := preload("res://ui/card_ui_resolver.gd")
const CARD_SIZE := Vector2(220, 360)

signal mount_requested(card: Resource, slot_idx: int, trait_id: String)
signal dismantle_requested(card: Resource, slot_idx: int)
signal reforge_requested(card: Resource)
signal slot_hovered(card: Resource, slot_idx: int, candidate_trait_id: String)
signal slot_unhovered(card: Resource, slot_idx: int)

@onready var _base_label: Label       = $Base
@onready var _icon_row: HBoxContainer = $IconRow
@onready var _effect_label: Label     = $Effect
@onready var _reforge_btn: Button     = $ReforgeBtn

var _card: Resource = null
var _locale: String = "zh_CN"
var _resolver: Object = null


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	_resolver = ResolverScript.new()
	_reforge_btn.pressed.connect(_on_reforge_pressed)


func bind(card: Resource, locale: String = "zh_CN") -> void:
	_card = card
	_locale = locale
	_base_label.text = card.base if card != null else ""
	_reforge_btn.disabled = card == null or bool(card.reforged)
	_render_slots()
	_render_effect()


func get_card() -> Resource:
	return _card


func _render_slots() -> void:
	for child in _icon_row.get_children():
		child.queue_free()
	if _card == null:
		return
	for i in range(3):
		var slot_node: Control = TraitIconScene.instantiate()
		_icon_row.add_child(slot_node)
		var slot: Resource = _card.slots[i]
		var t: Resource = slot.trait_ref
		slot_node.bind(t, slot.locked)
		# Wire drag-drop receiver on each slot via meta + a wrapper.
		slot_node.set_meta("slot_idx", i)
		slot_node.set_meta("card_camp_ui", self)
		slot_node.mouse_filter = Control.MOUSE_FILTER_PASS
		slot_node.gui_input.connect(_on_slot_gui_input.bind(i))
		slot_node.mouse_entered.connect(_on_slot_mouse_entered.bind(i))
		slot_node.mouse_exited.connect(_on_slot_mouse_exited.bind(i))
		slot_node.set_drag_forwarding(Callable(), Callable(self, "_can_drop_on_slot").bind(i), Callable(self, "_drop_on_slot").bind(i))


func _render_effect() -> void:
	if _card == null or _resolver == null:
		_effect_label.text = ""
		return
	_effect_label.text = _resolver.compose(_card, _locale)


# ---------------------------------------------------------------------------
# Drag-drop sink (ISSUE-013c)
# ---------------------------------------------------------------------------

func _can_drop_on_slot(_at: Vector2, data: Variant, slot_idx: int) -> bool:
	if _card == null or slot_idx == 0:  # base slot is locked
		return false
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if String(data.get("kind", "")) != "trait_drag":
		return false
	var tid: String = String(data.get("trait_id", ""))
	if tid.is_empty():
		return false
	# A2 §9.3 rule 1 — same card cannot hold two of the same trait id.
	for s in _card.slots:
		if s.trait_ref != null and s.trait_ref.id == tid:
			return false
	return true


func _drop_on_slot(_at: Vector2, data: Variant, slot_idx: int) -> void:
	var tid: String = String(data.get("trait_id", ""))
	mount_requested.emit(_card, slot_idx, tid)


func _on_slot_gui_input(event: InputEvent, slot_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if slot_idx == 0:
			return
		dismantle_requested.emit(_card, slot_idx)


func _on_slot_mouse_entered(slot_idx: int) -> void:
	# ISSUE-014b consumer reads the currently dragged trait from camp_scene.
	slot_hovered.emit(_card, slot_idx, "")


func _on_slot_mouse_exited(slot_idx: int) -> void:
	slot_unhovered.emit(_card, slot_idx)


func _on_reforge_pressed() -> void:
	if _card == null or bool(_card.reforged):
		return
	reforge_requested.emit(_card)
