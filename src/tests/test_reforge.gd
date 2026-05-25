## ISSUE-016a — Tests for reforge logic.
## Verifies cost gating, base swap, slot[0] replacement, slot 1/2 preservation,
## and once-per-card-per-run blocking.
extends GdUnitTestSuite

const TraitScript := preload("res://data/trait.gd")
const SlotScript  := preload("res://data/slot.gd")
const CardScript  := preload("res://data/card.gd")
const Reforge     := preload("res://core/reforge.gd")

const ON_PLAY: int = 0


func _trait(id: String) -> Resource:
	var t: Resource = TraitScript.new()
	t.id = id
	t.trigger = ON_PLAY
	t.effect_type = "Damage"
	t.effect_value = 1
	t.cooldown_per_turn = -1
	return t


func _slot(idx: int, t: Resource, locked: bool) -> Resource:
	var s: Resource = SlotScript.new()
	s.index = idx
	s.trait_ref = t
	s.locked = locked
	s.post_load()
	return s


func _card(base: String, t0: Resource, t1: Resource, t2: Resource) -> Resource:
	var c: Resource = CardScript.new()
	c.base = base
	c.slots = [_slot(0, t0, true), _slot(1, t1, false), _slot(2, t2, false)]
	return c


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_reforge_swaps_base_and_slot_zero_trait() -> void:
	var r: Object = Reforge.new()
	var card: Resource = _card("Attack", _trait("strike_t0"), _trait("ember"), _trait("oil"))
	var sig: Resource = _trait("rite_signature")

	var result: Dictionary = r.reforge(card, "Rite", sig, 200, 1)
	assert_bool(result["ok"]).is_true()
	assert_str(card.base).is_equal("Rite")
	assert_str(card.slots[0].trait_ref.id).is_equal("rite_signature")


func test_reforge_costs_100_gold_and_1_rare_item() -> void:
	var r: Object = Reforge.new()
	var card: Resource = _card("Attack", _trait("strike_t0"), null, null)
	var sig: Resource = _trait("rite_signature")

	var result: Dictionary = r.reforge(card, "Rite", sig, 200, 3)
	assert_int(result["gold_after"]).is_equal(100)
	assert_int(result["rare_items_after"]).is_equal(2)


func test_reforge_preserves_slot_1_and_2() -> void:
	# Whole point of the feature — PRD US-16 wording.
	var r: Object = Reforge.new()
	var card: Resource = _card("Attack", _trait("strike_t0"), _trait("ember"), _trait("oil"))
	var sig: Resource = _trait("rite_signature")

	r.reforge(card, "Rite", sig, 200, 1)
	assert_str(card.slots[1].trait_ref.id).is_equal("ember")
	assert_str(card.slots[2].trait_ref.id).is_equal("oil")


func test_slot_zero_remains_locked_after_reforge() -> void:
	var r: Object = Reforge.new()
	var card: Resource = _card("Attack", _trait("strike_t0"), null, null)
	var sig: Resource = _trait("rite_signature")

	r.reforge(card, "Rite", sig, 200, 1)
	assert_bool(card.slots[0].locked).is_true()


func test_second_reforge_blocked() -> void:
	var r: Object = Reforge.new()
	var card: Resource = _card("Attack", _trait("strike_t0"), null, null)
	var sig1: Resource = _trait("rite_signature")
	var sig2: Resource = _trait("skill_signature")

	var first: Dictionary = r.reforge(card, "Rite", sig1, 500, 5)
	assert_bool(first["ok"]).is_true()
	assert_bool(card.reforged).is_true()

	var second: Dictionary = r.reforge(card, "Skill", sig2, 500, 5)
	assert_bool(second["ok"]).is_false()
	assert_str(second["reason"]).is_equal("already_reforged")
	# State unchanged
	assert_str(card.base).is_equal("Rite")
	assert_str(card.slots[0].trait_ref.id).is_equal("rite_signature")


func test_reforge_blocked_without_gold() -> void:
	var r: Object = Reforge.new()
	var card: Resource = _card("Attack", _trait("strike_t0"), null, null)
	var sig: Resource = _trait("rite_signature")

	var result: Dictionary = r.reforge(card, "Rite", sig, 50, 1)
	assert_bool(result["ok"]).is_false()
	assert_str(result["reason"]).is_equal("insufficient_gold")
	# State unchanged
	assert_str(card.base).is_equal("Attack")
	assert_str(card.slots[0].trait_ref.id).is_equal("strike_t0")
	assert_bool(card.reforged).is_false()


func test_reforge_blocked_without_rare_item() -> void:
	var r: Object = Reforge.new()
	var card: Resource = _card("Attack", _trait("strike_t0"), null, null)
	var sig: Resource = _trait("rite_signature")

	var result: Dictionary = r.reforge(card, "Rite", sig, 200, 0)
	assert_bool(result["ok"]).is_false()
	assert_str(result["reason"]).is_equal("insufficient_rare_items")
	assert_bool(card.reforged).is_false()


func test_reforge_invalid_args_fails_safely() -> void:
	var r: Object = Reforge.new()

	var no_card: Dictionary = r.reforge(null, "Rite", _trait("x"), 200, 1)
	assert_bool(no_card["ok"]).is_false()

	var card: Resource = _card("Attack", _trait("strike_t0"), null, null)
	var no_sig: Dictionary = r.reforge(card, "Rite", null, 200, 1)
	assert_bool(no_sig["ok"]).is_false()

	var no_base: Dictionary = r.reforge(card, "", _trait("x"), 200, 1)
	assert_bool(no_base["ok"]).is_false()
