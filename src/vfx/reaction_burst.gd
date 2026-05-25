## ISSUE-011b — ReactionBurst VFX scene.
## A short (≤1.2s) burst that plays when an AnimSignaler emits
## reaction_triggered. Pure presentation: the burst tween-flashes a colored
## ColorRect over the card area and self-frees when done.
##
## Public API:
##   play(card_rect: Rect2, reaction_id: String, duration: float = 1.0)
##   connect_signaler(signaler: Node)   — auto-wires reaction_triggered hook
extends Node2D

const MAX_DURATION: float = 1.2

@onready var _flash: ColorRect = $Flash
@onready var _label: Label     = $Label

var _is_playing: bool = false


func _ready() -> void:
	_flash.modulate.a = 0.0
	_label.modulate.a = 0.0


## Subscribe to a signaler's reaction_triggered signal so the burst
## auto-plays whenever a reaction fires. The card_rect is resolved by
## subscribers at play-time (currently fixed Vector2.ZERO; battle wires it).
func connect_signaler(signaler: Node) -> void:
	if signaler == null:
		return
	if not signaler.has_signal("reaction_triggered"):
		return
	signaler.reaction_triggered.connect(_on_reaction_triggered)


func _on_reaction_triggered(reaction_id: String, _card: Resource) -> void:
	# Default play at origin; battle scene can override by replacing handler.
	play(Rect2(Vector2.ZERO, Vector2(160, 220)), reaction_id, 1.0)


## Trigger the burst over a card-shaped rect. Clamps duration to MAX_DURATION.
func play(card_rect: Rect2, reaction_id: String, duration: float = 1.0) -> void:
	if _is_playing:
		return
	var dur: float = clamp(duration, 0.1, MAX_DURATION)
	_is_playing = true
	position = card_rect.position
	_flash.size = card_rect.size
	_flash.color = _color_for(reaction_id)
	_label.text = reaction_id
	_label.position = Vector2(0, card_rect.size.y * 0.4)
	_label.size = Vector2(card_rect.size.x, 24)

	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(_flash, "modulate:a", 0.85, dur * 0.25)
	tween.tween_property(_label, "modulate:a", 1.0, dur * 0.25)
	tween.chain().tween_property(_flash, "modulate:a", 0.0, dur * 0.55)
	tween.chain().tween_property(_label, "modulate:a", 0.0, dur * 0.55)
	tween.chain().tween_callback(_on_burst_finished)


func _on_burst_finished() -> void:
	_is_playing = false


## Choose burst color based on the reaction id keyword.
func _color_for(reaction_id: String) -> Color:
	var lower: String = reaction_id.to_lower()
	if "fire" in lower or "flame" in lower:
		return Color(1.0, 0.55, 0.15, 1)
	if "void" in lower or "shadow" in lower:
		return Color(0.45, 0.20, 0.65, 1)
	if "lunar" in lower or "ice" in lower or "frost" in lower:
		return Color(0.55, 0.80, 1.00, 1)
	return Color(1.0, 0.95, 0.50, 1)


func is_playing() -> bool:
	return _is_playing
