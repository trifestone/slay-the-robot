## inventory_manager.gd — ISSUE-008: Inventory with capacity cap.
## RefCounted (no class_name to avoid Slay-The-Robot collision).
extends RefCounted

const CAPACITY: int = 5

## FIFO add. If at capacity, drops oldest (index 0) and pushes a warning string
## to warnings array. Mutates inventory and warnings in place. Returns inventory.
func add(inventory: Array, warnings: Array, trait_id: String) -> Array:
	if inventory.size() >= CAPACITY:
		var dropped: String = inventory[0]
		inventory.remove_at(0)
		warnings.append("inventory overflow: dropped '%s' to add '%s'" % [dropped, trait_id])
	inventory.append(trait_id)
	return inventory
