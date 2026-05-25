## ISSUE-018a — Meta-progression state machine (pure logic, AFK).
##
## Tracks cross-run progression: total runs, wins, XP, unlocked
## (witches/traits/bases/lore). Save format is a flat Dictionary that
## json-round-trips through `user://meta.json`. The actual file write
## happens in a thin scene wrapper (HITL); this module is pure.
##
## Public API:
##   make_default()                     -> Dictionary  (fresh meta)
##   apply_run_result(meta, summary)    -> Dictionary  (delta = unlocks granted + xp gained)
##                                          mutates meta in place; returns delta for UI
##   to_json(meta) -> String
##   from_json(json) -> Dictionary       (returns make_default() on parse failure)
##
## summary keys (caller — typically post-run):
##   won: bool
##   first_battle_death: bool         # US-15 min-reward path
##   traits_collected: Array[String]
##   trait_element_map: Dictionary    # for themed-build detection
##
## Min-reward (US-15): if first_battle_death = true, grant ≥1 XP fragment
## + 1 codex entry even though no thresholds fire normally.
extends RefCounted

const UnlockTable = preload("res://meta/unlock_table.gd")
const LoreStore   = preload("res://meta/lore_store.gd")

const XP_PER_LOSS: int = 1
const XP_PER_WIN: int  = 10


func make_default() -> Dictionary:
	return {
		"version":          1,
		"runs_total":       0,
		"wins_total":       0,
		"xp":               0,
		"unlocked_traits":  [],
		"unlocked_bases":   [],
		"unlocked_witches": ["witch_1"],   # starting witch
		"unlocked_lore":    [],
	}


## Apply a run result. Mutates `meta` in place and returns a delta describing
## what was newly granted (for the win/death screen popups).
func apply_run_result(meta: Dictionary, summary: Dictionary) -> Dictionary:
	var delta: Dictionary = {
		"xp_gained":      0,
		"new_unlocks":    [],   # Array[Dictionary] — same shape as unlock_table entries
	}

	meta["runs_total"] = int(meta["runs_total"]) + 1

	var won: bool = bool(summary.get("won", false))
	if won:
		meta["wins_total"] = int(meta["wins_total"]) + 1
		meta["xp"] = int(meta["xp"]) + XP_PER_WIN
		delta["xp_gained"] = XP_PER_WIN

		# Threshold-driven unlocks fire on the exact win count.
		var ut: Object = UnlockTable.new()
		var thresholds: Array = ut.unlocks_for_win_count(meta["wins_total"])
		for u in thresholds:
			if _grant(meta, u):
				delta["new_unlocks"].append(u)

		# Themed-build lore (US-14) — independent of count.
		var ls: Object = LoreStore.new()
		var themed_id: String = ls.fragment_for_themed_win(summary)
		if not themed_id.is_empty():
			var lu: Dictionary = {"kind": "lore", "id": themed_id}
			if _grant(meta, lu):
				delta["new_unlocks"].append(lu)
	else:
		meta["xp"] = int(meta["xp"]) + XP_PER_LOSS
		delta["xp_gained"] = XP_PER_LOSS

	# US-15 min-reward: first-battle death still grants ≥1 trait + 1 lore
	# entry (so the player doesn't bounce off run 1).
	if bool(summary.get("first_battle_death", false)):
		var min_trait: Dictionary = {"kind": "trait", "id": "trait_min_reward"}
		var min_lore: Dictionary  = {"kind": "lore",  "id": "lore_min_reward"}
		if _grant(meta, min_trait):
			delta["new_unlocks"].append(min_trait)
		if _grant(meta, min_lore):
			delta["new_unlocks"].append(min_lore)

	return delta


func to_json(meta: Dictionary) -> String:
	return JSON.stringify(meta)


func from_json(json: String) -> Dictionary:
	var parsed = JSON.parse_string(json)
	if parsed == null or not parsed is Dictionary:
		return make_default()
	# Defensive: backfill missing fields if a future version adds keys.
	var defaults: Dictionary = make_default()
	for k in defaults.keys():
		if not parsed.has(k):
			parsed[k] = defaults[k]
	return parsed


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

## Add `unlock` to the appropriate meta list. Returns true if it was new
## (i.e. actually granted), false if the player already had it.
func _grant(meta: Dictionary, unlock: Dictionary) -> bool:
	var kind: String = String(unlock["kind"])
	var id: String   = String(unlock["id"])
	var bucket: String = ""
	match kind:
		"trait":  bucket = "unlocked_traits"
		"base":   bucket = "unlocked_bases"
		"witch":  bucket = "unlocked_witches"
		"lore":   bucket = "unlocked_lore"
		_: return false

	var arr: Array = meta[bucket]
	if arr.has(id):
		return false
	arr.append(id)
	return true
