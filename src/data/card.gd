## TraitCard Resource — a base card with exactly 3 trait slots.
## Named TraitCard to avoid collision with the upstream Slay-the-Robot Card UI class.
## slot[0] is always locked and holds the base trait.
class_name TraitCard
extends Resource

## Base type string: "Attack" | "Skill" | "Rite".
@export var base: String = "Attack"

## Once-per-run reforge flag (PRD §3 US-16). True after the player has
## reforged this card's base; blocks further reforges.
@export var reforged: bool = false

## Three slots. Length MUST be 3 and slots[0].locked MUST be true.
## Use set_slots() to assign; direct mutation is validated via the setter.
var _slots: Array = []

@export var slots: Array:
	get:
		return _slots
	set(value):
		assert(value.size() == 3, "Card.slots must have exactly 3 elements")
		# Force slot indices and lock state.
		for i in range(3):
			var s = value[i]
			assert(s != null, "Card.slots[%d] must not be null" % i)
			s.index = i
			s.post_load()  # enforce locked state on slot[0]
		assert(value[0].locked == true, "Card.slots[0].locked must be true")
		_slots = value


## Convenience: get the trait at slot index i (0-2), or null if empty.
func get_trait_at(i: int) -> Resource:
	if i < 0 or i >= _slots.size():
		return null
	return _slots[i].trait_ref


## Returns all non-null traits across slots.
func all_traits() -> Array:
	var result: Array = []
	for s in _slots:
		if s.trait_ref != null:
			result.append(s.trait_ref)
	return result


## Returns true if the card has a trait with the given id.
func has_trait_id(trait_id: String) -> bool:
	for s in _slots:
		if s.trait_ref != null and s.trait_ref.id == trait_id:
			return true
	return false
