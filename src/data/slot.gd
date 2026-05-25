## Slot Resource — one of the three trait slots on a Card.
## slot[0] is always locked (holds the base trait).
class_name Slot
extends Resource

## Slot index: 0, 1, or 2.
@export var index: int = 0

## The trait socketed in this slot. May be null when empty.
@export var trait_ref: Resource = null  # typed as Trait at runtime

## When true the slot cannot be dismantled or replaced at camp.
## slot[0] MUST always be locked; enforced by the setter below.
var _locked: bool = false

@export var locked: bool:
	get:
		return _locked
	set(value):
		if index == 0:
			# slot[0] is permanently locked regardless of what caller sets.
			_locked = true
		else:
			_locked = value


## Helper to get the trait typed.
func get_trait() -> Resource:
	return trait_ref


## Called after loading from JSON to fix up lock state.
func post_load() -> void:
	if index == 0:
		_locked = true
