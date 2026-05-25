## ReactionRegistry — loads all SpecialReaction entries from data/reactions.json
## and provides a match helper for emit() integration.
##
## Usage:
##   var registry = preload("res://core/reaction_registry.gd").new()
##   var all := registry.load_all()      # inject into state.reactions
##   var hit := registry.find_match(card, event)  # optional convenience
##
## M2 validator: every reaction must have a valid TriggerEvent timing value.
## Invalid timing aborts loading with assert(false).
extends RefCounted

const LoaderScript := preload("res://data/loader.gd")

const REACTIONS_PATH := "res://data/reactions.json"

## Valid TriggerEvent int range: 0 (OnPlay) through 7 (OnTraitFired).
const TRIGGER_EVENT_MIN: int = 0
const TRIGGER_EVENT_MAX: int = 7


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Load all reactions from data/reactions.json.
## Validates timing field on each reaction (M2).
## Returns Array of Reaction resources.
func load_all() -> Array:
	var file := FileAccess.open(REACTIONS_PATH, FileAccess.READ)
	assert(file != null, "ReactionRegistry: cannot open '%s'" % REACTIONS_PATH)
	var text := file.get_as_text()
	file.close()

	var loader = LoaderScript.new()
	var reactions: Array = loader.load_reactions_from_json(text)

	# M2 validator: each reaction must have a valid timing.
	for r in reactions:
		_validate_reaction_timing(r)

	return reactions


## Optional helper: find the first reaction that matches both timing and watch_for.
## Returns the Reaction resource or null.
func find_match(card: Resource, event: int) -> Resource:
	var all: Array = load_all()
	for r in all:
		if r.timing == event and _card_has_all(card, r.watch_for):
			return r
	return null


# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

## M2 validator: asserts the reaction timing is a valid TriggerEvent int.
func _validate_reaction_timing(r: Resource) -> void:
	assert(
		r.timing >= TRIGGER_EVENT_MIN and r.timing <= TRIGGER_EVENT_MAX,
		"ReactionRegistry M2: reaction '%s' has invalid timing=%d (valid range %d-%d)" % [
			r.id, r.timing, TRIGGER_EVENT_MIN, TRIGGER_EVENT_MAX
		]
	)


## Returns true when every trait id in watch_for_ids is present on card.
func _card_has_all(card: Resource, watch_for_ids: Array) -> bool:
	for tid in watch_for_ids:
		if not card.has_trait_id(tid):
			return false
	return true
