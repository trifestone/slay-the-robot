## ISSUE-014a — Reaction Predictor (pure logic, AFK).
## During camp drag-drop, the player needs to know which reactions
## a candidate mount would gain or lose BEFORE committing. This
## resolver computes the diff between the card's current reaction
## set and the hypothetical reaction set after the swap, without
## mutating any state.
##
## Public API:
##   diff_for_mount(card, slot_idx, candidate_trait, reactions, event=ON_PLAY)
##     -> { before: Array[String], after: Array[String],
##          added: Array[String], removed: Array[String], unchanged: Array[String] }
##
## `reactions` is an Array of Reaction resources (the camp scene passes
## ReactionRegistry.load_all() once at session start). `event` filters
## reactions to a single timing — defaults to OnPlay because the camp
## tooltip cares about play-phase reactions, but callers can pass any
## TriggerEvent. Pass -1 to disable timing filter (predict across all
## events).
extends RefCounted

const ON_PLAY: int = 0


## Compute reaction diff for swapping `candidate_trait` into `slot_idx` on `card`.
## Does not mutate card or candidate_trait.
func diff_for_mount(card: Resource, slot_idx: int, candidate_trait: Resource,
		reactions: Array, event: int = ON_PLAY) -> Dictionary:
	if card == null or slot_idx < 0 or slot_idx >= card.slots.size():
		return _empty()

	var before_ids: Dictionary = {}  # trait id → true
	for s in card.slots:
		if s.trait_ref != null:
			before_ids[s.trait_ref.id] = true

	var after_ids: Dictionary = before_ids.duplicate()
	# Remove what was in slot_idx (if anything).
	var existing: Resource = card.slots[slot_idx].trait_ref
	if existing != null:
		after_ids.erase(existing.id)
	# Add the candidate (caller's responsibility to ensure non-null when
	# they want a real swap; null candidate = pure-removal preview).
	if candidate_trait != null:
		after_ids[candidate_trait.id] = true

	var before: Array = _matching_reaction_ids(before_ids, reactions, event)
	var after: Array  = _matching_reaction_ids(after_ids, reactions, event)

	var before_set: Dictionary = {}
	for id in before:
		before_set[id] = true
	var after_set: Dictionary = {}
	for id in after:
		after_set[id] = true

	var added: Array = []
	for id in after:
		if not before_set.has(id):
			added.append(id)
	var removed: Array = []
	for id in before:
		if not after_set.has(id):
			removed.append(id)
	var unchanged: Array = []
	for id in before:
		if after_set.has(id):
			unchanged.append(id)

	return {
		"before": before,
		"after": after,
		"added": added,
		"removed": removed,
		"unchanged": unchanged,
	}


## Compute reaction diff for dismantling slot_idx (removes whatever is there).
## Convenience wrapper around diff_for_mount(..., null).
func diff_for_dismantle(card: Resource, slot_idx: int, reactions: Array,
		event: int = ON_PLAY) -> Dictionary:
	return diff_for_mount(card, slot_idx, null, reactions, event)


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _empty() -> Dictionary:
	return {
		"before": [],
		"after": [],
		"added": [],
		"removed": [],
		"unchanged": [],
	}


func _matching_reaction_ids(trait_ids: Dictionary, reactions: Array, event: int) -> Array:
	var matches: Array = []
	for r in reactions:
		if r == null:
			continue
		if event != -1 and int(r.timing) != event:
			continue
		var all_present: bool = true
		for need in r.watch_for:
			if not trait_ids.has(need):
				all_present = false
				break
		if all_present and r.watch_for.size() > 0:
			matches.append(String(r.id))
	return matches
