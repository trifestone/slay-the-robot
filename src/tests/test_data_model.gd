## GdUnit4 test suite for ISSUE-002: Trait + Card data model.
## Tests: JSON round-trip, slot[0] locked invariant, M1 validator, flame_brand sample.
extends GdUnitTestSuite

# Preload all data scripts directly — avoids class_name scan-order issues.
const TraitScript    := preload("res://data/trait.gd")
const SlotScript     := preload("res://data/slot.gd")
const CardScript     := preload("res://data/card.gd")
const ReactionScript := preload("res://data/reaction.gd")
const LoaderScript   := preload("res://data/loader.gd")

const TRAITS_JSON_PATH    := "res://data/traits.json"
const REACTIONS_JSON_PATH := "res://data/reactions.json"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_that(f).is_not_null()
	var text := f.get_as_text()
	f.close()
	return text


func _make_loader():
	return LoaderScript.new()


func _load_traits() -> Array:
	var text := _read_file(TRAITS_JSON_PATH)
	return _make_loader().load_traits_from_json(text)


# ---------------------------------------------------------------------------
# Test 1: JSON load round-trip
# ---------------------------------------------------------------------------

func test_json_roundtrip() -> void:
	var loader = _make_loader()
	var traits := loader.load_traits_from_json(_read_file(TRAITS_JSON_PATH))
	assert_int(traits.size()).is_equal(80)

	for t in traits:
		assert_that(t).is_not_null()
		var d: Dictionary = loader.trait_to_dict(t)

		# Round-trip: re-serialize to JSON and reload.
		var json_text := JSON.stringify([d])
		var reloaded: Array = loader.load_traits_from_json(json_text)
		assert_int(reloaded.size()).is_equal(1)
		var r = reloaded[0]

		assert_str(r.id).is_equal(t.id)
		assert_int(r.trigger).is_equal(t.trigger)
		assert_str(r.effect_type).is_equal(t.effect_type)
		assert_int(r.effect_value).is_equal(t.effect_value)
		assert_int(r.axis_school).is_equal(t.axis_school)
		assert_int(r.rarity).is_equal(t.rarity)
		assert_int(r.cooldown_per_turn).is_equal(t.cooldown_per_turn)
		assert_bool(r.removable).is_equal(t.removable)


# ---------------------------------------------------------------------------
# Test 2: slot[0].locked invariant
# ---------------------------------------------------------------------------

func test_slot0_always_locked() -> void:
	var s0 = SlotScript.new()
	s0.index = 0
	var base_trait = TraitScript.new()
	base_trait.id = "flame_brand"
	s0.trait_ref = base_trait
	s0.locked = true
	s0.post_load()

	var s1 = SlotScript.new()
	s1.index = 1
	s1.locked = false
	s1.post_load()

	var s2 = SlotScript.new()
	s2.index = 2
	s2.locked = false
	s2.post_load()

	var card = CardScript.new()
	card.slots = [s0, s1, s2]

	assert_bool(card.slots[0].locked).is_true()
	assert_bool(card.slots[1].locked).is_false()
	assert_bool(card.slots[2].locked).is_false()


func test_slot0_locked_cannot_be_unset() -> void:
	# Explicitly set locked=false on slot index=0 — must stay true.
	var s0 = SlotScript.new()
	s0.index = 0
	s0.locked = false   # attempt to unlock
	s0.post_load()       # enforce

	assert_bool(s0.locked).is_true()


# ---------------------------------------------------------------------------
# Test 3: M1 validator catches missing cooldown on OnKill / OnTraitFired
# ---------------------------------------------------------------------------

func test_validator_catches_onkill_without_cooldown() -> void:
	var loader = _make_loader()
	var bad_trait = TraitScript.new()
	bad_trait.id = "bad_kill_trait"
	bad_trait.trigger = 3           # OnKill
	bad_trait.cooldown_per_turn = -1

	# assert(false) inside _validate_trait emits a script runtime error.
	await assert_error(func(): loader._validate_trait(bad_trait)) \
		.is_runtime_error(any())


func test_validator_accepts_onkill_with_cooldown() -> void:
	var loader = _make_loader()
	var good_trait = TraitScript.new()
	good_trait.id = "good_kill_trait"
	good_trait.trigger = 3          # OnKill
	good_trait.cooldown_per_turn = 1
	loader._validate_trait(good_trait)   # must not raise
	assert_bool(true).is_true()


func test_validator_catches_ontraitfired_without_cooldown() -> void:
	var loader = _make_loader()
	var bad_trait = TraitScript.new()
	bad_trait.id = "bad_otf_trait"
	bad_trait.trigger = 7           # OnTraitFired
	bad_trait.cooldown_per_turn = -1

	await assert_error(func(): loader._validate_trait(bad_trait)) \
		.is_runtime_error(any())


# ---------------------------------------------------------------------------
# Test 4: flame_brand Trait exists with correct trigger and school
# ---------------------------------------------------------------------------

func test_flame_brand_fields() -> void:
	var traits := _load_traits()

	var flame_brand = null
	for t in traits:
		if t.id == "flame_brand":
			flame_brand = t
			break

	assert_that(flame_brand).is_not_null()
	assert_int(flame_brand.trigger).is_equal(0)           # OnPlay
	assert_int(flame_brand.axis_school).is_equal(0)       # Fire
	assert_int(flame_brand.rarity).is_equal(0)            # Common
	assert_int(flame_brand.cooldown_per_turn).is_equal(-1) # unlimited


# ---------------------------------------------------------------------------
# Test 5: reactions JSON loads correctly
# ---------------------------------------------------------------------------

func test_reactions_load() -> void:
	var loader = _make_loader()
	var reactions: Array = loader.load_reactions_from_json(_read_file(REACTIONS_JSON_PATH))
	assert_int(reactions.size()).is_greater_equal(2)

	var r0 = reactions[0]
	assert_str(r0.id).is_equal("fire_oil_explosion")
	assert_int(r0.watch_for.size()).is_equal(2)
	assert_bool(r0.watch_for.has("flame_brand")).is_true()
	assert_bool(r0.watch_for.has("oil_slick")).is_true()
	assert_int(r0.timing).is_equal(0)   # OnPlay


# ---------------------------------------------------------------------------
# Test 6: void_consume has cooldown_per_turn >= 1
# ---------------------------------------------------------------------------

func test_void_consume_has_cooldown() -> void:
	var traits := _load_traits()
	var vc = null
	for t in traits:
		if t.id == "void_consume":
			vc = t
			break
	assert_that(vc).is_not_null()
	assert_int(vc.cooldown_per_turn).is_greater_equal(1)


# ---------------------------------------------------------------------------
# Test 7: bone_harvest (OnKill) has cooldown_per_turn >= 1
# ---------------------------------------------------------------------------

func test_bone_harvest_has_cooldown() -> void:
	var traits := _load_traits()
	var bh = null
	for t in traits:
		if t.id == "bone_harvest":
			bh = t
			break
	assert_that(bh).is_not_null()
	assert_int(bh.cooldown_per_turn).is_greater_equal(1)
