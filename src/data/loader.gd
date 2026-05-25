## TraitLoader — reads data/traits.json and data/reactions.json and produces
## typed Resource instances (Trait, Reaction).
##
## M1 validator: traits with trigger ∈ {OnTraitFired, OnKill} MUST have
## cooldown_per_turn >= 1.  Violation aborts loading with assert(false).
class_name TraitLoader
extends RefCounted

# Preload dependencies so they're always available.
const TraitScript    := preload("res://data/trait.gd")
const ReactionScript := preload("res://data/reaction.gd")


# ---------------------------------------------------------------------------
# String → enum int helpers
# ---------------------------------------------------------------------------

func _trigger_from_str(s: String) -> int:
	match s:
		"OnPlay":        return 0
		"OnDraw":        return 1
		"OnDiscard":     return 2
		"OnKill":        return 3
		"OnHit":         return 4
		"StartTurn":     return 5
		"EndTurn":       return 6
		"OnTraitFired":  return 7
		_:
			assert(false, "TraitLoader: unknown TriggerEvent '%s'" % s)
			return 0


func _school_from_str(s: String) -> int:
	match s:
		"Fire":   return 0
		"Decay":  return 1
		"Moon":   return 2
		"Iron":   return 3
		"Bone":   return 4
		"Void":   return 5
		_:
			assert(false, "TraitLoader: unknown School '%s'" % s)
			return 0


func _scope_from_str(s: String) -> int:
	match s:
		"Self":        return 0
		"Card":        return 1
		"Hand":        return 2
		"Battlefield": return 3
		_:
			assert(false, "TraitLoader: unknown Scope '%s'" % s)
			return 0


func _rarity_from_str(s: String) -> int:
	match s:
		"Common":   return 0
		"Uncommon": return 1
		"Rare":     return 2
		_:
			assert(false, "TraitLoader: unknown Rarity '%s'" % s)
			return 0


# ---------------------------------------------------------------------------
# M1 validator
# ---------------------------------------------------------------------------

## Validates a single Trait resource.
## Triggers that require cooldown_per_turn >= 1:
##   OnKill (3) and OnTraitFired (7).
func _validate_trait(t: Resource) -> void:
	if t.trigger == 3 or t.trigger == 7:
		assert(
			t.cooldown_per_turn >= 1,
			"M1 violation: trait '%s' has trigger '%s' but cooldown_per_turn=%d (must be >= 1)" % [
				t.id,
				["OnPlay","OnDraw","OnDiscard","OnKill","OnHit","StartTurn","EndTurn","OnTraitFired"][t.trigger],
				t.cooldown_per_turn
			]
		)


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Load all traits from a JSON array string.  Returns Array of Trait resources.
func load_traits_from_json(json_text: String) -> Array:
	var parsed = JSON.parse_string(json_text)
	assert(parsed != null, "TraitLoader: failed to parse traits JSON")
	assert(parsed is Array, "TraitLoader: traits JSON root must be an Array")

	var result: Array = []
	for entry in parsed:
		var t = TraitScript.new()
		t.id             = entry.get("id", "")
		t.trigger        = _trigger_from_str(entry.get("trigger", "OnPlay"))
		t.effect_type    = entry.get("effect_type", "")
		t.effect_value   = int(entry.get("effect_value", 0))
		t.axis_timing    = _trigger_from_str(entry.get("axis_timing", entry.get("trigger", "OnPlay")))
		t.axis_scope     = _scope_from_str(entry.get("axis_scope", "Self"))
		t.axis_school    = _school_from_str(entry.get("axis_school", "Fire"))
		t.rarity         = _rarity_from_str(entry.get("rarity", "Common"))
		t.cooldown_per_turn = int(entry.get("cooldown_per_turn", -1))
		t.removable      = bool(entry.get("removable", true))
		t.flavor         = entry.get("flavor", "")

		_validate_trait(t)
		result.append(t)
	return result


## Load all reactions from a JSON array string.  Returns Array of Reaction resources.
func load_reactions_from_json(json_text: String) -> Array:
	var parsed = JSON.parse_string(json_text)
	assert(parsed != null, "TraitLoader: failed to parse reactions JSON")
	assert(parsed is Array, "TraitLoader: reactions JSON root must be an Array")

	var result: Array = []
	for entry in parsed:
		var r = ReactionScript.new()
		r.id              = entry.get("id", "")
		r.watch_for       = Array(entry.get("watch_for", []))
		r.timing          = _trigger_from_str(entry.get("timing", "OnPlay"))
		r.override_effect = entry.get("override_effect", "")
		r.flavor          = entry.get("flavor", "")
		result.append(r)
	return result


## Dump a Trait resource back to a Dictionary (round-trip helper).
func trait_to_dict(t: Resource) -> Dictionary:
	var trigger_names := ["OnPlay","OnDraw","OnDiscard","OnKill","OnHit","StartTurn","EndTurn","OnTraitFired"]
	var school_names  := ["Fire","Decay","Moon","Iron","Bone","Void"]
	var scope_names   := ["Self","Card","Hand","Battlefield"]
	var rarity_names  := ["Common","Uncommon","Rare"]

	return {
		"id":                t.id,
		"trigger":           trigger_names[t.trigger],
		"effect_type":       t.effect_type,
		"effect_value":      t.effect_value,
		"axis_timing":       trigger_names[t.axis_timing],
		"axis_scope":        scope_names[t.axis_scope],
		"axis_school":       school_names[t.axis_school],
		"rarity":            rarity_names[t.rarity],
		"cooldown_per_turn": t.cooldown_per_turn,
		"removable":         t.removable,
		"flavor":            t.flavor,
	}


## Convenience: load traits from a file path (res:// or absolute).
func load_traits_from_file(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "TraitLoader: cannot open file '%s'" % path)
	var text := file.get_as_text()
	file.close()
	return load_traits_from_json(text)


## Convenience: load reactions from a file path.
func load_reactions_from_file(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	assert(file != null, "TraitLoader: cannot open file '%s'" % path)
	var text := file.get_as_text()
	file.close()
	return load_reactions_from_json(text)
