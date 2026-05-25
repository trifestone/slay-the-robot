## Trait Resource — one atomic trait that can be socketed into a card slot.
## Fields match PRD §4.1 exactly.
class_name Trait
extends Resource

## Unique string identifier, e.g. "flame_brand".
@export var id: String = ""

## When this trait fires (TriggerEvent enum value stored as int).
@export var trigger: int = 0  # Enums.TriggerEvent.OnPlay

## Effect type string, e.g. "Damage", "Apply", "Draw", "Spawn", "HealSelfPercent".
@export var effect_type: String = ""

## Numeric effect parameter (may be 0 when not applicable).
@export var effect_value: int = 0

## Three-axis classification -------------------------------------------------
## axis_timing mirrors trigger for orthogonal classification.
@export var axis_timing: int = 0   # Enums.TriggerEvent

## Scope of effect (Enums.Scope value stored as int).
@export var axis_scope: int = 0    # Enums.Scope.Self

## School / element (Enums.School value stored as int).
@export var axis_school: int = 0   # Enums.School.Fire

## Rarity (Enums.Rarity value stored as int).
@export var rarity: int = 0        # Enums.Rarity.Common

## M1 cooldown: null == no per-turn limit; N >= 1 == fire at most N times/turn.
## Stored as -1 to represent null (GDScript Resource cannot export Variant null cleanly).
## Use get_cooldown() to get true value (returns -1 when unlimited).
@export var cooldown_per_turn: int = -1

## Whether this trait can be dismantled at camp and put in inventory.
@export var removable: bool = true

## Flavour text.
@export var flavor: String = ""


## Returns true when this trait has a per-turn fire limit.
func has_cooldown() -> bool:
	return cooldown_per_turn >= 1


## Convenience: returns the cooldown limit, or -1 when unlimited.
func get_cooldown() -> int:
	return cooldown_per_turn
