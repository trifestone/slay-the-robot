## ISSUE-010b — EnemyUI Control: 180×260 composite enemy widget.
## Combines IntentWidget (top) + sprite placeholder (middle) + HP bar/label
## + carried_traits row (bottom). Drives PRD §3 US-02 "看意图" loop.
##
## Public API:
##   bind(enemy, hp, max_hp, intent_value, locale)
##   update_hp(new_hp)              — partial refresh between turns
extends Control

const TraitIconScene := preload("res://ui/trait_icon.tscn")
const IntentWidgetScene := preload("res://ui/intent_widget.tscn")
const TraitScript := preload("res://data/trait.gd")

const ENEMY_SIZE := Vector2(180, 260)

## Emitted when the player left-clicks the enemy widget.
## BattleScene uses this to resolve a target-selected damage card.
signal enemy_clicked()

@onready var _intent_slot: Control = $IntentSlot
@onready var _body_sprite: TextureRect = $Body/BodySprite
@onready var _hp_label: Label      = $HpLabel
@onready var _hp_bar: ProgressBar  = $HpBar
@onready var _trait_row: HBoxContainer = $TraitRow

var _enemy: Resource = null
var _hp: int = 0
var _max_hp: int = 0
var _locale: String = "zh_CN"

var _intent_widget: Control = null


func _ready() -> void:
	custom_minimum_size = ENEMY_SIZE
	_intent_widget = IntentWidgetScene.instantiate()
	_intent_slot.add_child(_intent_widget)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			enemy_clicked.emit()


## Bind enemy + hp + intent value. Re-renders all subviews.
func bind(enemy: Resource, hp: int, max_hp: int, intent_value: int = 0, locale: String = "zh_CN", sprite: Texture2D = null) -> void:
	_enemy = enemy
	_hp = hp
	_max_hp = max_hp
	_locale = locale
	_render_intent(intent_value)
	_render_hp()
	_render_carried()
	set_sprite(sprite)


## Assign a sprite texture to the enemy body. Pass null to show the fallback color.
func set_sprite(tex: Texture2D = null) -> void:
	_body_sprite.texture = tex


## Update only the HP labels/bar (no need to rebuild trait row mid-turn).
func update_hp(new_hp: int) -> void:
	_hp = new_hp
	_render_hp()


func _render_intent(value: int) -> void:
	if _enemy == null or _intent_widget == null:
		return
	_intent_widget.bind(_enemy.intent, value, _locale)


func _render_hp() -> void:
	_hp_label.text = "%d / %d" % [_hp, _max_hp]
	_hp_bar.max_value = max(_max_hp, 1)
	_hp_bar.value = _hp


func _render_carried() -> void:
	for child in _trait_row.get_children():
		child.queue_free()
	if _enemy == null:
		return
	for t in _enemy.carried_traits:
		var icon: Control = TraitIconScene.instantiate()
		_trait_row.add_child(icon)
		# carried_traits in Enemy may be Trait Resources OR id strings.
		# Normalize to a Resource so trait_icon.bind() works either way.
		var resolved: Resource = _resolve_trait(t)
		icon.bind(resolved, false)


## Accepts either a Trait Resource directly or a string id (legacy data path).
## When given a string, builds a stub Trait so the icon row has something to render.
func _resolve_trait(value) -> Resource:
	if value == null:
		return null
	if typeof(value) == TYPE_STRING:
		var stub: Resource = TraitScript.new()
		stub.id = value
		stub.axis_school = 3  # Iron / gray neutral default when school unknown
		return stub
	return value
