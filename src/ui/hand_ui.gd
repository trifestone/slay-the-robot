## ISSUE-009b — HandUI: fan layout of CardUI instances bound to BattleState.hand.
##
## Cards are arranged in an arc (slight per-card rotation + drop) so the row
## reads as "held in hand" rather than flat. Hovering a card lifts it, levels
## its rotation, and brings it to the front. The "Row" child is kept as a
## Control so battle_scene._hook_hand_card_signals() can iterate its children
## the same way it did with the old HBoxContainer.
extends Control

const CardUIScene := preload("res://ui/card_ui.tscn")

const HAND_BOTTOM_MARGIN: int = 24
const HAND_HEIGHT: float = 360.0

const CARD_W: float = 220.0
const CARD_H: float = 320.0

## Horizontal step between adjacent card centers. Smaller than CARD_W → cards overlap.
const CARD_X_STEP: float = 130.0
## Per-step rotation (degrees) — card[i] rotates by (i - mid) * FAN_ANGLE_DEG.
const FAN_ANGLE_DEG: float = 5.0
## Per-step extra y-drop so edge cards sit lower than the center.
const FAN_Y_DROP: float = 14.0

## Hover-lift visuals.
const HOVER_LIFT: float = 48.0
const HOVER_SCALE: float = 1.06
const TWEEN_DUR: float = 0.16

@onready var _row: Control = $Row

var _state: RefCounted = null
var _locale: String = "zh_CN"


func _ready() -> void:
	anchor_left = 0.0
	anchor_right = 1.0
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_top = -HAND_HEIGHT
	offset_bottom = -float(HAND_BOTTOM_MARGIN)


## Bind a BattleState and re-render the hand fan.
func bind(state: RefCounted, locale: String = "zh_CN") -> void:
	_state = state
	_locale = locale
	_render()


func _render() -> void:
	for child in _row.get_children():
		child.queue_free()
	if _state == null:
		return
	var cards: Array = _state.hand
	var n: int = cards.size()
	for i in range(n):
		var ui: Control = CardUIScene.instantiate()
		_row.add_child(ui)
		ui.bind(cards[i], 1, _locale)
		_apply_fan_layout(ui, i, n)
		ui.card_hovered.connect(_on_card_hovered.bind(ui))
		ui.card_unhovered.connect(_on_card_unhovered.bind(ui))


## Position card[i] of n in an arc anchored at the bottom-center of the hand area.
func _apply_fan_layout(card_ui: Control, i: int, n: int) -> void:
	var hand_w: float = _row.size.x
	if hand_w <= 0.0:
		hand_w = size.x
	var center_x: float = hand_w * 0.5
	var base_card_y: float = HAND_HEIGHT - CARD_H - float(HAND_BOTTOM_MARGIN)

	var offset_from_mid: float = float(i) - float(n - 1) * 0.5
	var card_x: float = center_x + offset_from_mid * CARD_X_STEP - CARD_W * 0.5
	var card_y: float = base_card_y + abs(offset_from_mid) * FAN_Y_DROP
	var rot_deg: float = offset_from_mid * FAN_ANGLE_DEG

	card_ui.size = Vector2(CARD_W, CARD_H)
	card_ui.pivot_offset = Vector2(CARD_W * 0.5, CARD_H * 0.5)
	card_ui.position = Vector2(card_x, card_y)
	card_ui.rotation_degrees = rot_deg
	card_ui.set_meta("base_pos", card_ui.position)
	card_ui.set_meta("base_rot", rot_deg)


func _on_card_hovered(_card: Resource, ui: Control) -> void:
	if not is_instance_valid(ui):
		return
	_row.move_child(ui, _row.get_child_count() - 1)
	var base_pos: Vector2 = ui.get_meta("base_pos", ui.position)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(ui, "position", base_pos + Vector2(0, -HOVER_LIFT), TWEEN_DUR)
	tw.tween_property(ui, "rotation_degrees", 0.0, TWEEN_DUR)
	tw.tween_property(ui, "scale", Vector2(HOVER_SCALE, HOVER_SCALE), TWEEN_DUR)


func _on_card_unhovered(_card: Resource, ui: Control) -> void:
	if not is_instance_valid(ui):
		return
	var base_pos: Vector2 = ui.get_meta("base_pos", ui.position)
	var base_rot: float = ui.get_meta("base_rot", 0.0)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(ui, "position", base_pos, TWEEN_DUR)
	tw.tween_property(ui, "rotation_degrees", base_rot, TWEEN_DUR)
	tw.tween_property(ui, "scale", Vector2.ONE, TWEEN_DUR)


# ---------------------------------------------------------------------------
# Card dealing animation (Optimization 2)
# ---------------------------------------------------------------------------

## Animate dealing cards one by one with a delay between each.
## Cards start off-screen/deck position and fly into hand position.
## on_complete: called after all cards are dealt.
func animate_deal(cards: Array, locale: String, deck_pos: Vector2, on_complete: Callable = Callable()) -> void:
	# Clear existing cards first
	for child in _row.get_children():
		child.queue_free()
	
	if cards.is_empty():
		if on_complete.is_valid():
			on_complete.call()
		return
	
	_locale = locale
	var deal_delay: float = 0.25  # seconds between each card
	
	for i in range(cards.size()):
		var card: Resource = cards[i]
		var ui: Control = CardUIScene.instantiate()
		_row.add_child(ui)
		ui.bind(card, 1, _locale)
		
		# Calculate final position
		var hand_w: float = _row.size.x if _row.size.x > 0 else size.x
		var center_x: float = hand_w * 0.5
		var base_card_y: float = HAND_HEIGHT - CARD_H - float(HAND_BOTTOM_MARGIN)
		var offset_from_mid: float = float(i) - float(cards.size() - 1) * 0.5
		var card_x: float = center_x + offset_from_mid * CARD_X_STEP - CARD_W * 0.5
		var card_y: float = base_card_y + abs(offset_from_mid) * FAN_Y_DROP
		var rot_deg: float = offset_from_mid * FAN_ANGLE_DEG
		var final_pos: Vector2 = Vector2(card_x, card_y)
		
		# Start from deck position
		ui.position = deck_pos
		ui.rotation_degrees = 0.0
		ui.scale = Vector2(0.5, 0.5)  # Start smaller
		ui.modulate.a = 0.0
		
		# Set metadata for hover
		ui.set_meta("base_pos", final_pos)
		ui.set_meta("base_rot", rot_deg)
		ui.size = Vector2(CARD_W, CARD_H)
		ui.pivot_offset = Vector2(CARD_W * 0.5, CARD_H * 0.5)
		
		# Connect hover signals
		ui.card_hovered.connect(_on_card_hovered.bind(ui))
		ui.card_unhovered.connect(_on_card_unhovered.bind(ui))
		
		# Animate to hand position with delay
		var tw: Tween = create_tween()
		tw.tween_interval(deal_delay * i)
		tw.chain().tween_property(ui, "position", final_pos, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(ui, "rotation_degrees", rot_deg, 0.3)
		tw.parallel().tween_property(ui, "scale", Vector2.ONE, 0.3)
		tw.parallel().tween_property(ui, "modulate:a", 1.0, 0.2)
		
		# Call completion after last card
		if i == cards.size() - 1 and on_complete.is_valid():
			tw.chain().tween_callback(on_complete)
