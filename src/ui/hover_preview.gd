## ISSUE-012a — HoverPreview pure-logic resolver.
## When the player hovers a card, this resolves what would happen if it were
## played right now — without mutating real state. Returns a Dictionary the
## .tscn view consumes:
##
##   {
##     "card": <Card Resource>,
##     "steps":      Array[Dictionary],   # one entry per fire (trait or reaction)
##     "damage_estimate": int,            # sum of effect_value for "Damage" steps
##     "reaction_overrides": Array[String]  # reaction ids that would fire
##   }
##
## Each step Dictionary mirrors a state.trait_fire_log entry with two added keys:
##   "is_reaction" (bool) and "label" (String — pre-rendered for the tooltip).
##
## Pure logic — no side effects on the caller's state. Headless-testable.
extends RefCounted

const EmitScript := preload("res://core/emit.gd")
const ON_PLAY: int = 0  # Enums.TriggerEvent.OnPlay


## Resolve a hover preview for `card` against `state`. Does not mutate state.
## Returns a preview Dictionary (see file header).
func resolve(state: Object, card: Resource, event: int = ON_PLAY) -> Dictionary:
	if state == null or card == null:
		return _empty(card)

	# Snapshot mutable fields emit() touches.
	var snap_log: Array     = state.trait_fire_log.duplicate(true)
	var snap_cd: Dictionary = state.cooldown_table.duplicate(true)
	var snap_depth: int     = state.fire_depth

	var before: int = state.trait_fire_log.size()
	var emitter: Object = EmitScript.new()
	emitter.emit(state, event, card)
	var new_entries: Array = state.trait_fire_log.slice(before, state.trait_fire_log.size())

	# Restore. Do not assign trait_fire_log = snap_log directly without
	# clearing in case something else holds the array reference; rewrite in place.
	state.trait_fire_log.clear()
	for e in snap_log:
		state.trait_fire_log.append(e)
	state.cooldown_table.clear()
	for k in snap_cd.keys():
		state.cooldown_table[k] = snap_cd[k]
	state.fire_depth = snap_depth

	return _format(card, new_entries)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _empty(card: Resource) -> Dictionary:
	return {
		"card": card,
		"steps": [],
		"damage_estimate": 0,
		"reaction_overrides": [],
	}


func _format(card: Resource, entries: Array) -> Dictionary:
	var steps: Array = []
	var damage: int = 0
	var rx_ids: Array = []

	for entry in entries:
		var is_rx: bool = entry.get("source", "") == "reaction"
		var label: String = _render_label(entry, is_rx)
		var step: Dictionary = entry.duplicate()
		step["is_reaction"] = is_rx
		step["label"] = label
		steps.append(step)

		if is_rx:
			rx_ids.append(String(entry.get("id", "")))
			damage += _estimate_damage_from_override(String(entry.get("effect_type", "")))
		else:
			if String(entry.get("effect_type", "")) == "Damage":
				damage += int(entry.get("effect_value", 0))

	return {
		"card": card,
		"steps": steps,
		"damage_estimate": damage,
		"reaction_overrides": rx_ids,
	}


## Render a one-line label for the tooltip step list.
##   trait:     "[depth] alpha → Damage(4)"
##   reaction:  "★ fire_oil_explosion → Damage(12, Fire) + AOE_Splash(4)"
func _render_label(entry: Dictionary, is_rx: bool) -> String:
	if is_rx:
		return "★ %s → %s" % [entry.get("id", ""), entry.get("effect_type", "")]
	var depth: int = int(entry.get("depth", 0))
	var tid: String = String(entry.get("source_trait_id", ""))
	var et: String  = String(entry.get("effect_type", ""))
	var ev: int     = int(entry.get("effect_value", 0))
	if ev != 0:
		return "[%d] %s → %s(%d)" % [depth, tid, et, ev]
	return "[%d] %s → %s" % [depth, tid, et]


## Best-effort numeric extraction from a reaction override string like
## "Damage(12, Fire) + AOE_Splash(4)". Returns the first integer found
## inside parentheses after a "Damage" keyword. Returns 0 if absent.
func _estimate_damage_from_override(override: String) -> int:
	var lower: String = override.to_lower()
	var idx: int = lower.find("damage(")
	if idx < 0:
		return 0
	var open_paren: int = override.find("(", idx)
	if open_paren < 0:
		return 0
	var close_paren: int = override.find(")", open_paren)
	if close_paren < 0:
		return 0
	var inside: String = override.substr(open_paren + 1, close_paren - open_paren - 1)
	# Take the first comma-separated token that parses as a number.
	for tok in inside.split(","):
		var trimmed: String = tok.strip_edges()
		if trimmed.is_valid_int():
			return int(trimmed)
	return 0
