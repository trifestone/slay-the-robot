## ISSUE-018a — Lore fragment store + themed-build detection (PRD US-14).
##
## The lore catalogue is small enough to inline here; expansion lives in
## a future content pass (lore_fragments.json) without changing the API.
##
## Public API:
##   all_fragments() -> Array[Dictionary]
##   fragment_by_id(id) -> Dictionary | null
##   fragment_for_themed_win(run_summary) -> String   # "" if none qualifies
##
## A "themed build" is any run where ≥80% of the player's collected traits
## share an element. The detector takes a run_summary {traits_collected: Array,
## won: bool} and returns a lore id (or empty string).
extends RefCounted

const FRAGMENTS := [
	{"id": "lore_first_win", "title": "Ash on the Hearth", "body": "After the first storm, the witch lit a single coal."},
	{"id": "lore_run5",      "title": "Five Embers",        "body": "Five fires marked the road; she walked them in turn."},
	{"id": "lore_themed_fire", "title": "All Flame, No Doubt", "body": "She did not balance the elements. She burned through them."},
	{"id": "lore_themed_void", "title": "Hollow Verses",       "body": "What was hollow she filled with hollower things."},
]

const THEMED_THRESHOLD: float = 0.80


func all_fragments() -> Array:
	var out: Array = []
	for f in FRAGMENTS:
		out.append(f.duplicate(true))
	return out


func fragment_by_id(id: String) -> Variant:
	for f in FRAGMENTS:
		if f["id"] == id:
			return f.duplicate(true)
	return null


## Detect themed-build win and return the lore id, or "" if none.
## `run_summary` keys:
##   won: bool
##   traits_collected: Array[String]    # trait ids
##   trait_element_map: Dictionary      # trait_id -> element name (caller-supplied
##                                       # so this module stays decoupled from JSON)
func fragment_for_themed_win(run_summary: Dictionary) -> String:
	if not run_summary.get("won", false):
		return ""
	var traits: Array = run_summary.get("traits_collected", [])
	if traits.is_empty():
		return ""

	var element_map: Dictionary = run_summary.get("trait_element_map", {})
	var counts: Dictionary = {}
	for tid in traits:
		var el: String = String(element_map.get(tid, "Neutral"))
		counts[el] = int(counts.get(el, 0)) + 1

	var dominant: String = ""
	var dominant_count: int = 0
	for el in counts:
		if int(counts[el]) > dominant_count:
			dominant = el
			dominant_count = int(counts[el])

	var ratio: float = float(dominant_count) / float(traits.size())
	if ratio < THEMED_THRESHOLD:
		return ""

	match dominant:
		"Fire": return "lore_themed_fire"
		"Void": return "lore_themed_void"
		_:      return ""
