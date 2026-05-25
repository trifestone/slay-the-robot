## ISSUE-011b — DevourKill VFX scene.
## Plays when an AnimSignaler fires enemy_killed. Two-stage burst:
##   Stage 1 (0..0.4s): enemy sprite tints black + collapses inward
##   Stage 2 (0.4..1.2s): drop trait icons fan upward as toast badges
##
## Public API:
##   play(enemy_rect: Rect2, enemy_name: String, drops: Array, duration: float = 1.2)
##   connect_signaler(signaler: Node)
extends Node2D

const MAX_DURATION: float = 1.2
const TraitIconScene := preload("res://ui/trait_icon.tscn")
const TraitScript    := preload("res://data/trait.gd")

@onready var _devour: ColorRect = $Devour
@onready var _name_label: Label = $NameLabel
@onready var _drop_row: HBoxContainer = $DropRow

var _is_playing: bool = false


func _ready() -> void:
	_devour.modulate.a = 0.0
	_name_label.modulate.a = 0.0


## Subscribe to a signaler so the kill auto-plays.
func connect_signaler(signaler: Node) -> void:
	if signaler == null:
		return
	if not signaler.has_signal("enemy_killed"):
		return
	signaler.enemy_killed.connect(_on_enemy_killed)


func _on_enemy_killed(enemy: Resource, drops: Array) -> void:
	var enemy_name: String = ""
	if enemy != null and "id" in enemy:
		enemy_name = String(enemy.id)
	play(Rect2(Vector2.ZERO, Vector2(180, 240)), enemy_name, drops, 1.2)


## Trigger the devour + drop fan. duration clamped to MAX_DURATION.
func play(enemy_rect: Rect2, enemy_name: String, drops: Array, duration: float = 1.2) -> void:
	if _is_playing:
		return
	_is_playing = true
	var dur: float = clamp(duration, 0.4, MAX_DURATION)

	position = enemy_rect.position
	_devour.size = enemy_rect.size
	_devour.color = Color(0.05, 0.0, 0.10, 1.0)
	_name_label.text = enemy_name
	_name_label.position = Vector2(0, enemy_rect.size.y * 0.45)
	_name_label.size = Vector2(enemy_rect.size.x, 22)

	_clear_drops()
	_populate_drops(drops)
	_drop_row.position = Vector2(0, enemy_rect.size.y + 4)
	_drop_row.size = Vector2(enemy_rect.size.x, 30)
	_drop_row.modulate.a = 0.0

	var tween: Tween = create_tween()
	tween.tween_property(_devour, "modulate:a", 0.9, dur * 0.30)
	tween.parallel().tween_property(_name_label, "modulate:a", 1.0, dur * 0.30)
	tween.tween_property(_drop_row, "modulate:a", 1.0, dur * 0.25)
	tween.tween_property(_drop_row, "position:y", _drop_row.position.y - 18, dur * 0.30)
	tween.parallel().tween_property(_devour, "modulate:a", 0.0, dur * 0.30)
	tween.parallel().tween_property(_name_label, "modulate:a", 0.0, dur * 0.30)
	tween.tween_property(_drop_row, "modulate:a", 0.0, dur * 0.15)
	tween.tween_callback(_on_devour_finished)


func _on_devour_finished() -> void:
	_is_playing = false
	_clear_drops()


func _clear_drops() -> void:
	for child in _drop_row.get_children():
		child.queue_free()


func _populate_drops(drops: Array) -> void:
	for d in drops:
		var icon: Control = TraitIconScene.instantiate()
		_drop_row.add_child(icon)
		var resolved: Resource = _resolve(d)
		icon.bind(resolved, false)


## drops can hold Trait Resources or id strings — normalize like enemy_ui.
func _resolve(value) -> Resource:
	if value == null:
		return null
	if typeof(value) == TYPE_STRING:
		var stub: Resource = TraitScript.new()
		stub.id = value
		stub.axis_school = 3
		return stub
	return value


func is_playing() -> bool:
	return _is_playing
