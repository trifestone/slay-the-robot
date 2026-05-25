## ISSUE-013b — DeckPanel: vertical scroll list of CardCampUI instances.
## Re-emits child signals upward so camp_scene can route to camp_state.
extends Control

const CardCampUIScene := preload("res://ui/camp/card_camp_ui.tscn")

signal mount_requested(card: Resource, slot_idx: int, trait_id: String)
signal dismantle_requested(card: Resource, slot_idx: int)
signal reforge_requested(card: Resource)
signal slot_hovered(card: Resource, slot_idx: int, candidate_trait_id: String)
signal slot_unhovered(card: Resource, slot_idx: int)

@onready var _row: HBoxContainer = $Scroll/Row

var _cards: Array = []
var _locale: String = "zh_CN"


func bind(cards: Array, locale: String = "zh_CN") -> void:
	_cards = cards
	_locale = locale
	_render()


func _render() -> void:
	for child in _row.get_children():
		child.queue_free()
	for card in _cards:
		var ui: Control = CardCampUIScene.instantiate()
		_row.add_child(ui)
		ui.bind(card, _locale)
		ui.mount_requested.connect(_relay_mount)
		ui.dismantle_requested.connect(_relay_dismantle)
		ui.reforge_requested.connect(_relay_reforge)
		ui.slot_hovered.connect(_relay_slot_hovered)
		ui.slot_unhovered.connect(_relay_slot_unhovered)


func refresh() -> void:
	_render()


func _relay_mount(card: Resource, slot_idx: int, trait_id: String) -> void:
	mount_requested.emit(card, slot_idx, trait_id)


func _relay_dismantle(card: Resource, slot_idx: int) -> void:
	dismantle_requested.emit(card, slot_idx)


func _relay_reforge(card: Resource) -> void:
	reforge_requested.emit(card)


func _relay_slot_hovered(card: Resource, slot_idx: int, candidate_trait_id: String) -> void:
	slot_hovered.emit(card, slot_idx, candidate_trait_id)


func _relay_slot_unhovered(card: Resource, slot_idx: int) -> void:
	slot_unhovered.emit(card, slot_idx)
