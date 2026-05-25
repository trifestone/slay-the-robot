## SpecialReaction Resource — a high-priority override triggered when a card
## simultaneously holds all traits listed in watch_for and the event matches timing.
class_name Reaction
extends Resource

## Unique identifier for this reaction, e.g. "fire_oil_explosion".
@export var id: String = ""

## The trait ids that must ALL be present on the same card (Array[String]).
@export var watch_for: Array = []

## The TriggerEvent that must be emitted for this reaction to activate
## (M2 requirement: each reaction is bound to a specific timing).
## Stored as int matching Enums.TriggerEvent.
@export var timing: int = 0  # Enums.TriggerEvent.OnPlay

## Override effect string, e.g. "Damage(12, Fire) + AOE_Splash(4)".
@export var override_effect: String = ""

## Flavour text, e.g. "火 + 油 → 爆炸".
@export var flavor: String = ""
