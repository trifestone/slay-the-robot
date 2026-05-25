## ISSUE-009b — CardUI: visual representation of a TraitCard in hand.
## Layout (220×320 placeholder, fits 5 cards on 1280×720 viewport):
##   ┌──────────────────────┐
##   │ [cost]      [base]   │
##   │                      │
##   │   ┌──┐ ┌──┐ ┌──┐     │  3 trait_icons (slot 0 has lock badge)
##   │   └──┘ └──┘ └──┘     │
##   │                      │
##   │  composed effect     │  multi-line label, locale-aware
##   └──────────────────────┘
extends Control

const TraitIconScene := preload("res://ui/trait_icon.tscn")
const ResolverScript := preload("res://ui/card_ui_resolver.gd")

const CARD_SIZE := Vector2(220, 320)

## Emitted when the card is left-clicked. BattleScene subscribes to route
## the click into BattleLoop.play_card(state, card, null).
signal card_clicked(card: Resource)

## Emitted when the cursor enters/exits the card area. BattleScene routes
## these into HoverPreview.resolve and HoverPreviewView.show_for/hide.
signal card_hovered(card: Resource)
signal card_unhovered(card: Resource)

@onready var _cost_label: Label    = $Cost
@onready var _base_label: Label    = $Base
@onready var _icon_row: HBoxContainer = $IconRow
@onready var _effect_label: Label  = $Effect

var _card: Resource = null
var _locale: String = "zh_CN"
var _resolver: Object = null


func _ready() -> void:
	custom_minimum_size = CARD_SIZE
	_resolver = ResolverScript.new()
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(_card)


func _on_mouse_entered() -> void:
	card_hovered.emit(_card)


func _on_mouse_exited() -> void:
	card_unhovered.emit(_card)


## Bind a TraitCard Resource and trigger a re-render.
## locale: "zh_CN" or "en"
func bind(card: Resource, energy_cost: int = 1, locale: String = "zh_CN") -> void:
	_card = card
	_locale = locale
	_cost_label.text = str(energy_cost)
	_base_label.text = card.base if card != null else ""
	_render_icons()
	_render_effect()


func _render_icons() -> void:
	for child in _icon_row.get_children():
		child.queue_free()
	if _card == null:
		return
	for i in range(3):
		var icon: Control = TraitIconScene.instantiate()
		_icon_row.add_child(icon)
		var slot: Resource = _card.slots[i]
		var t: Resource = slot.trait_ref
		icon.bind(t, slot.locked)


func _render_effect() -> void:
	if _card == null or _resolver == null:
		_effect_label.text = ""
		return
	_effect_label.text = _resolver.compose(_card, _locale)
