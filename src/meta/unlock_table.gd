## ISSUE-018a — Unlock thresholds (PRD §4.6 元进度).
##
## Pure data: maps win_count → unlocks granted at that exact threshold.
## meta_state.gd consults this when applying a run result. New thresholds
## are added by editing this file; tests pin the table to PRD numbers.
##
## Public API:
##   unlocks_for_win_count(win_count) -> Array[Dictionary]
##     Returns the list of {kind, id, ...} unlocks that fire when the
##     player's total wins becomes exactly `win_count`. Empty array if
##     no threshold matches.
##
## Unlock kinds:
##   {"kind": "trait",  "id": String}
##   {"kind": "base",   "id": String}     # card base (Attack/Skill/Rite)
##   {"kind": "witch",  "id": String}     # playable character
##   {"kind": "lore",   "id": String}     # lore fragment
extends RefCounted

## PRD §4.6 thresholds — keep in sync with the design table.
const TABLE := {
	1: [
		{"kind": "trait", "id": "trait_unlock_run1"},
		{"kind": "lore",  "id": "lore_first_win"},
	],
	5: [
		{"kind": "witch", "id": "witch_2"},
		{"kind": "base",  "id": "base_unlock_run5"},
		{"kind": "trait", "id": "trait_unlock_run5_a"},
		{"kind": "trait", "id": "trait_unlock_run5_b"},
		{"kind": "lore",  "id": "lore_run5"},
	],
	20: [
		{"kind": "witch", "id": "witch_3"},
		{"kind": "trait", "id": "trait_unlock_run20"},
	],
	50: [
		{"kind": "trait", "id": "trait_unlock_run50_full_pool"},
	],
}


func unlocks_for_win_count(win_count: int) -> Array:
	if not TABLE.has(win_count):
		return []
	return (TABLE[win_count] as Array).duplicate(true)


## Convenience: enumerate all unlock thresholds in ascending order.
## Used by test code to pin the table layout.
func thresholds() -> Array:
	var keys: Array = TABLE.keys()
	keys.sort()
	return keys
