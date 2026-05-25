## ISSUE-012b — HoverPreviewView Control.
## Tooltip-style panel showing the resolved emit() trace for a hovered card.
## Layout: 280×220 panel:
##   ┌───────────────────────────────┐
##   │ Title (card hint)             │
##   │ ─────────────────────         │
##   │ ★ fire_oil_explosion → ...    │  (StepList VBox)
##   │ [0] alpha → Damage(4)         │
##   │ [1] beta  → Block(2)          │
##   │ ─────────────────────         │
##   │ Estimated damage: 12          │
##   └───────────────────────────────┘
##
## Public API:
##   show_for(card, state, anchor_position, locale="zh_CN")
##   hide_preview()
##   set_hover_delay_ms(ms)            — default 300, per US-04 spec
##   begin_hover(card, state, anchor)  — starts the delay timer
##   cancel_hover()                    — cancels pending timer
##
## Drives PRD §3 US-04 "悬浮预览" loop. Pure view layer; the resolver
## (hover_preview.gd) handles state.
extends Control

const HoverPreviewLogic := preload("res://ui/hover_preview.gd")

const PANEL_SIZE := Vector2(220, 120)
const DEFAULT_HOVER_DELAY_MS: int = 300

@onready var _title: Label         = $Panel/Title
@onready var _step_list: VBoxContainer = $Panel/StepList
@onready var _damage_label: Label  = $Panel/DamageLabel

var _resolver: Object = null
var _hover_delay_ms: int = DEFAULT_HOVER_DELAY_MS
var _pending_card: Resource = null
var _pending_state: Object = null
var _pending_anchor: Vector2 = Vector2.ZERO
var _delay_timer: Timer = null


func _ready() -> void:
	custom_minimum_size = PANEL_SIZE
	visible = false
	_resolver = HoverPreviewLogic.new()
	_delay_timer = Timer.new()
	_delay_timer.one_shot = true
	add_child(_delay_timer)
	_delay_timer.timeout.connect(_on_delay_timeout)


## US-04: 300ms hover dwell before tooltip appears.
func set_hover_delay_ms(ms: int) -> void:
	_hover_delay_ms = max(0, ms)


## Start a delayed show. Cancel any in-flight pending show.
func begin_hover(card: Resource, state: Object, anchor_position: Vector2) -> void:
	cancel_hover()
	_pending_card = card
	_pending_state = state
	_pending_anchor = anchor_position
	_delay_timer.wait_time = max(_hover_delay_ms, 1) / 1000.0
	_delay_timer.start()


## Cancel a pending show OR hide if visible.
func cancel_hover() -> void:
	if _delay_timer != null and not _delay_timer.is_stopped():
		_delay_timer.stop()
	hide_preview()


func _on_delay_timeout() -> void:
	if _pending_card == null or _pending_state == null:
		return
	show_for(_pending_card, _pending_state, _pending_anchor)


## Show the preview immediately (skips the 300ms delay).
func show_for(card: Resource, state: Object, anchor_position: Vector2,
		_locale: String = "zh_CN") -> void:
	if _resolver == null:
		_resolver = HoverPreviewLogic.new()
	var preview: Dictionary = _resolver.resolve(state, card, 0)  # ON_PLAY
	_render(preview)
	position = anchor_position
	visible = true


func hide_preview() -> void:
	visible = false
	_pending_card = null
	_pending_state = null


func _render(preview: Dictionary) -> void:
	_title.text = "预览"
	# Clear old step rows
	for child in _step_list.get_children():
		child.queue_free()
	for step in preview["steps"]:
		var row: Label = Label.new()
		row.text = String(step["label"])
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.clip_text = false
		row.add_theme_font_size_override("font_size", 12)
		if bool(step["is_reaction"]):
			row.add_theme_color_override("font_color", Color(1.0, 0.85, 0.30))
		_step_list.add_child(row)
	_damage_label.text = "预计伤害:%d" % int(preview["damage_estimate"])


# ---------------------------------------------------------------------------
# Test hooks
# ---------------------------------------------------------------------------

func is_pending() -> bool:
	return _delay_timer != null and not _delay_timer.is_stopped()


func get_step_count() -> int:
	return _step_list.get_child_count()


func get_damage_text() -> String:
	return _damage_label.text
