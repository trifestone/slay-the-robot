## Inventory Resource — holds dismantled traits between battles.
class_name Inventory
extends Resource

## Traits currently stored but not socketed into any card.
@export var unsocketed: Array = []  # Array[Trait]

## Maximum number of traits this inventory can hold.
## Starting capacity is 5; expands after each boss (CONTEXT §5 R3).
@export var capacity: int = 5


## Returns true if there is room to add another trait.
func has_space() -> bool:
	return unsocketed.size() < capacity


## Add a trait to the inventory. Returns false if full.
func add_trait(t: Resource) -> bool:
	if not has_space():
		return false
	unsocketed.append(t)
	return true


## Remove and return a trait by id. Returns null if not found.
func remove_trait_by_id(trait_id: String) -> Resource:
	for i in range(unsocketed.size()):
		if unsocketed[i].id == trait_id:
			return unsocketed.pop_at(i)
	return null
