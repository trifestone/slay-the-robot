## ISSUE-018c — HealPop VFX: floating "+N" number that drifts upward and
## fades out. Used by shop heal purchase, camp rest events, and any other
## heal-on-the-fly feedback where the player needs a transient confirmation
## that an HP change happened.
##
## Public API:
##   play(world_pos: Vector2, amount: int, color: Color = green, duration: float = 1.0)
##
## Lifecycle: tween fades in (~0.15s) → drifts up by RISE_PIXELS → fades out
## (~0.45s) → queue_free. Total ~1.0s by default.
extends Node2D

const RISE_PIXELS: float    = 48.0
const MAX_DURATION: float   = 1.5
const DEFAULT_COLOR: Color  = Color(0.45, 0.95, 0.45, 1)
const DAMAGE_COLOR: Color   = Color(0.95, 0.45, 0.45, 1)

@onready var _label: Label = $Label

var _is_playing: bool = false


func _ready() -> void:
	_label.modulate.a = 0.0


## Spawn a +N float at world_pos. Positive amount renders as "+N" (heal),
## negative amount renders as "-N" (damage) with a red tint.
func play(world_pos: Vector2, amount: int, color: Color = DEFAULT_COLOR, duration: float = 1.0) -> void:
	if _is_playing:
		return
	_is_playing = true
	position = world_pos

	var prefix: String = "+" if amount >= 0 else ""
	_label.text = "%s%d" % [prefix, amount]
	_label.modulate = Color(color.r, color.g, color.b, 0.0)

	var dur: float = clamp(duration, 0.2, MAX_DURATION)
	var fade_in: float    = dur * 0.15
	var hold_rise: float  = dur * 0.40
	var fade_out: float   = dur * 0.45

	var start_y: float = 0.0
	var end_y: float   = -RISE_PIXELS

	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_label, "modulate:a", 1.0, fade_in)
	tw.tween_property(_label, "position:y", start_y - 6.0, fade_in)

	tw.chain().tween_property(_label, "position:y", end_y * 0.6, hold_rise)

	tw.chain().tween_property(_label, "modulate:a", 0.0, fade_out)
	tw.chain().tween_property(_label, "position:y", end_y, fade_out)

	tw.chain().tween_callback(queue_free)


## Convenience helper: spawn a damage variant with red tint.
func play_damage(world_pos: Vector2, amount: int, duration: float = 1.0) -> void:
	play(world_pos, -abs(amount), DAMAGE_COLOR, duration)


## Resist variant: show "抵消 N" in blue when block absorbs incoming damage.
func play_resist(world_pos: Vector2, amount: int, duration: float = 1.0) -> void:
	play_with_label(world_pos, "抵消 %d" % amount, Color(0.55, 0.75, 1.0, 1), duration)


## Generic labelled float — caller controls text and color directly.
func play_with_label(world_pos: Vector2, text: String, color: Color, duration: float = 1.0) -> void:
	if _is_playing:
		return
	_is_playing = true
	position = world_pos

	_label.text = text
	_label.modulate = Color(color.r, color.g, color.b, 0.0)

	var dur: float = clamp(duration, 0.2, MAX_DURATION)
	var fade_in: float    = dur * 0.15
	var hold_rise: float  = dur * 0.40
	var fade_out: float   = dur * 0.45

	var start_y: float = 0.0
	var end_y: float   = -RISE_PIXELS

	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_label, "modulate:a", 1.0, fade_in)
	tw.tween_property(_label, "position:y", start_y - 6.0, fade_in)

	tw.chain().tween_property(_label, "position:y", end_y * 0.6, hold_rise)

	tw.chain().tween_property(_label, "modulate:a", 0.0, fade_out)
	tw.chain().tween_property(_label, "position:y", end_y, fade_out)

	tw.chain().tween_callback(queue_free)


func is_playing() -> bool:
	return _is_playing
