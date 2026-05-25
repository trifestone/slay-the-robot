## ISSUE-017b — MapNode: a single node circle on the StS-style tree map.
##
## Renders an icon by node type (Normal/Elite/Shop/Camp/Event/Boss),
## a faded look when unreachable, a pulse when current, and a click
## handler that emits node_selected(id) only if reachable.
##
## Public API:
##   bind(node_data, state, locale)
##     node_data = {id, type, act, floor, col}
##     state ∈ {"current", "reachable", "visited", "unreachable"}
##
## Signals:
##   node_selected(id: String)
extends Control

const NODE_SIZE := Vector2(64, 64)

signal node_selected(id: String)

@onready var _circle: ColorRect = $Circle
@onready var _label: Label      = $Label
@onready var _btn: Button       = $Button

var _id: String = ""
var _state: String = "unreachable"


func _ready() -> void:
	custom_minimum_size = NODE_SIZE
	_btn.pressed.connect(_on_pressed)


func bind(node_data: Dictionary, state: String, locale: String = "zh_CN") -> void:
	_id = String(node_data.get("id", ""))
	_state = state
	var t: String = String(node_data.get("type", "Normal"))
	_label.text = _short(t, locale)
	_circle.color = _color_for_type(t)
	_apply_state()


func _apply_state() -> void:
	match _state:
		"current":
			modulate = Color(1, 1, 1, 1)
			_btn.disabled = true
			_pulse()
		"reachable":
			modulate = Color(1, 1, 1, 1)
			_btn.disabled = false
		"visited":
			modulate = Color(0.55, 0.55, 0.55, 1)
			_btn.disabled = true
		"unreachable", _:
			modulate = Color(0.45, 0.45, 0.45, 0.7)
			_btn.disabled = true


func _pulse() -> void:
	var tw: Tween = create_tween().set_loops()
	tw.tween_property(_circle, "modulate", Color(1.2, 1.2, 1.2, 1), 0.6)
	tw.tween_property(_circle, "modulate", Color(1, 1, 1, 1), 0.6)


func _on_pressed() -> void:
	if _state == "reachable":
		node_selected.emit(_id)


func _color_for_type(t: String) -> Color:
	match t:
		"Normal": return Color(0.55, 0.55, 0.65, 1)
		"Elite":  return Color(0.85, 0.45, 0.30, 1)
		"Shop":   return Color(0.85, 0.75, 0.35, 1)
		"Camp":   return Color(0.40, 0.65, 0.45, 1)
		"Event":  return Color(0.55, 0.45, 0.75, 1)
		"Boss":   return Color(0.90, 0.25, 0.25, 1)
		_:        return Color(0.5, 0.5, 0.5, 1)


func _short(t: String, locale: String) -> String:
	if locale != "zh_CN":
		return t.substr(0, 1)
	match t:
		"Normal": return "战"
		"Elite":  return "精"
		"Shop":   return "店"
		"Camp":   return "营"
		"Event":  return "?"
		"Boss":   return "BOSS"
		_: return t
