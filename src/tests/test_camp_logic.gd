## ISSUE-013a — Tests for camp_state mount/dismantle transactions.
## Covers all six acceptance gates from ISSUE-013:
##   1. empty mount free
##   2. replace mount 30g
##   3. dismantle 50g + 1 point
##   4. slot[0] immutable
##   5. full inventory blocks dismantle
##   6. duplicate trait on same card blocked
extends GdUnitTestSuite

const TraitScript     := preload("res://data/trait.gd")
const SlotScript      := preload("res://data/slot.gd")
const CardScript      := preload("res://data/card.gd")
const InventoryScript := preload("res://data/inventory.gd")
const CampState       := preload("res://core/camp_state.gd")

const ON_PLAY: int = 0


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _trait(id: String, removable: bool = true) -> Resource:
	var t: Resource = TraitScript.new()
	t.id = id
	t.trigger = ON_PLAY
	t.effect_type = "Damage"
	t.effect_value = 3
	t.cooldown_per_turn = -1
	t.removable = removable
	return t


func _slot(idx: int, t: Resource, locked: bool) -> Resource:
	var s: Resource = SlotScript.new()
	s.index = idx
	s.trait_ref = t
	s.locked = locked
	s.post_load()
	return s


func _card(t0: Resource, t1: Resource, t2: Resource) -> Resource:
	var c: Resource = CardScript.new()
	c.slots = [_slot(0, t0, true), _slot(1, t1, false), _slot(2, t2, false)]
	return c


func _inventory(traits: Array, capacity: int = 5) -> Resource:
	var inv: Resource = InventoryScript.new()
	inv.capacity = capacity
	for t in traits:
		inv.add_trait(t)
	return inv


# ---------------------------------------------------------------------------
# Gate 1: empty mount is free
# ---------------------------------------------------------------------------

func test_mount_to_empty_slot_is_free() -> void:
	var camp: Object = CampState.new()
	var base: Resource = _trait("alpha")
	var card: Resource = _card(base, null, null)
	var newt: Resource = _trait("beta")
	var inv: Resource = _inventory([newt])

	var r: Dictionary = camp.mount_trait_to_slot(card, 1, newt, 100, 2, inv)
	assert_bool(r["ok"]).is_true()
	assert_int(r["gold_after"]).is_equal(100)
	assert_int(r["dismantle_after"]).is_equal(2)
	assert_str(card.slots[1].trait_ref.id).is_equal("beta")
	assert_int(inv.unsocketed.size()).is_equal(0)


# ---------------------------------------------------------------------------
# Gate 2: replace costs 30 gold
# ---------------------------------------------------------------------------

func test_mount_replace_existing_costs_30_gold() -> void:
	var camp: Object = CampState.new()
	var base: Resource = _trait("alpha")
	var old: Resource = _trait("beta")
	var newt: Resource = _trait("gamma")
	var card: Resource = _card(base, old, null)
	var inv: Resource = _inventory([newt])

	var r: Dictionary = camp.mount_trait_to_slot(card, 1, newt, 100, 2, inv)
	assert_bool(r["ok"]).is_true()
	assert_int(r["gold_after"]).is_equal(70)
	assert_str(card.slots[1].trait_ref.id).is_equal("gamma")
	# old trait is "replaced" — caller may push it back into inventory if desired
	assert_object(r["replaced_trait"]).is_not_null()
	assert_str(r["replaced_trait"].id).is_equal("beta")


func test_mount_replace_blocked_when_gold_short() -> void:
	var camp: Object = CampState.new()
	var card: Resource = _card(_trait("alpha"), _trait("beta"), null)
	var newt: Resource = _trait("gamma")
	var inv: Resource = _inventory([newt])

	var r: Dictionary = camp.mount_trait_to_slot(card, 1, newt, 10, 2, inv)
	assert_bool(r["ok"]).is_false()
	assert_str(r["reason"]).is_equal("insufficient_gold")
	# State unchanged
	assert_str(card.slots[1].trait_ref.id).is_equal("beta")
	assert_int(inv.unsocketed.size()).is_equal(1)


# ---------------------------------------------------------------------------
# Gate 3: dismantle costs 50g + 1 point and returns trait to inventory
# ---------------------------------------------------------------------------

func test_dismantle_costs_50_gold_and_1_point() -> void:
	var camp: Object = CampState.new()
	var card: Resource = _card(_trait("alpha"), _trait("beta"), null)
	var inv: Resource = _inventory([])

	var r: Dictionary = camp.dismantle_slot(card, 1, 100, 2, inv)
	assert_bool(r["ok"]).is_true()
	assert_int(r["gold_after"]).is_equal(50)
	assert_int(r["dismantle_after"]).is_equal(1)
	assert_object(card.slots[1].trait_ref).is_null()
	assert_int(inv.unsocketed.size()).is_equal(1)
	assert_str(inv.unsocketed[0].id).is_equal("beta")


func test_dismantle_blocked_without_gold() -> void:
	var camp: Object = CampState.new()
	var card: Resource = _card(_trait("alpha"), _trait("beta"), null)
	var inv: Resource = _inventory([])

	var r: Dictionary = camp.dismantle_slot(card, 1, 20, 2, inv)
	assert_bool(r["ok"]).is_false()
	assert_str(r["reason"]).is_equal("insufficient_gold")
	assert_object(card.slots[1].trait_ref).is_not_null()


func test_dismantle_blocked_without_dismantle_points() -> void:
	var camp: Object = CampState.new()
	var card: Resource = _card(_trait("alpha"), _trait("beta"), null)
	var inv: Resource = _inventory([])

	var r: Dictionary = camp.dismantle_slot(card, 1, 100, 0, inv)
	assert_bool(r["ok"]).is_false()
	assert_str(r["reason"]).is_equal("insufficient_dismantle_points")


# ---------------------------------------------------------------------------
# Gate 4: slot[0] is immutable
# ---------------------------------------------------------------------------

func test_mount_slot_0_blocked() -> void:
	var camp: Object = CampState.new()
	var card: Resource = _card(_trait("alpha"), null, null)
	var newt: Resource = _trait("beta")
	var inv: Resource = _inventory([newt])

	var r: Dictionary = camp.mount_trait_to_slot(card, 0, newt, 100, 2, inv)
	assert_bool(r["ok"]).is_false()
	assert_str(r["reason"]).is_equal("slot_locked")
	assert_str(card.slots[0].trait_ref.id).is_equal("alpha")


func test_dismantle_slot_0_blocked() -> void:
	var camp: Object = CampState.new()
	var card: Resource = _card(_trait("alpha"), null, null)
	var inv: Resource = _inventory([])

	var r: Dictionary = camp.dismantle_slot(card, 0, 100, 2, inv)
	assert_bool(r["ok"]).is_false()
	assert_str(r["reason"]).is_equal("slot_locked")
	assert_str(card.slots[0].trait_ref.id).is_equal("alpha")


# ---------------------------------------------------------------------------
# Gate 5: full inventory blocks dismantle
# ---------------------------------------------------------------------------

func test_dismantle_blocked_when_inventory_full() -> void:
	var camp: Object = CampState.new()
	var card: Resource = _card(_trait("alpha"), _trait("beta"), null)
	# capacity=2 with 2 items already inside → no room for dismantled trait
	var inv: Resource = _inventory([_trait("x"), _trait("y")], 2)

	var r: Dictionary = camp.dismantle_slot(card, 1, 100, 2, inv)
	assert_bool(r["ok"]).is_false()
	assert_str(r["reason"]).is_equal("inventory_full")
	assert_object(card.slots[1].trait_ref).is_not_null()
	assert_int(inv.unsocketed.size()).is_equal(2)


# ---------------------------------------------------------------------------
# Gate 6: duplicate trait on same card blocked
# ---------------------------------------------------------------------------

func test_mount_duplicate_trait_id_blocked() -> void:
	var camp: Object = CampState.new()
	# Card already has "beta" in slot 1
	var card: Resource = _card(_trait("alpha"), _trait("beta"), null)
	var dup: Resource = _trait("beta")
	var inv: Resource = _inventory([dup])

	var r: Dictionary = camp.mount_trait_to_slot(card, 2, dup, 100, 2, inv)
	assert_bool(r["ok"]).is_false()
	assert_str(r["reason"]).is_equal("duplicate_trait")
	assert_object(card.slots[2].trait_ref).is_null()
	assert_int(inv.unsocketed.size()).is_equal(1)


# ---------------------------------------------------------------------------
# Misc edge cases
# ---------------------------------------------------------------------------

func test_dismantle_empty_slot_returns_error() -> void:
	var camp: Object = CampState.new()
	var card: Resource = _card(_trait("alpha"), null, null)
	var inv: Resource = _inventory([])

	var r: Dictionary = camp.dismantle_slot(card, 1, 100, 2, inv)
	assert_bool(r["ok"]).is_false()
	assert_str(r["reason"]).is_equal("slot_empty")


func test_dismantle_non_removable_trait_blocked() -> void:
	var camp: Object = CampState.new()
	var stuck: Resource = _trait("permanent", false)  # removable=false
	var card: Resource = _card(_trait("alpha"), stuck, null)
	var inv: Resource = _inventory([])

	var r: Dictionary = camp.dismantle_slot(card, 1, 100, 2, inv)
	assert_bool(r["ok"]).is_false()
	assert_str(r["reason"]).is_equal("trait_not_removable")


func test_mount_with_invalid_slot_index_fails() -> void:
	var camp: Object = CampState.new()
	var card: Resource = _card(_trait("alpha"), null, null)
	var newt: Resource = _trait("beta")
	var inv: Resource = _inventory([newt])

	var r: Dictionary = camp.mount_trait_to_slot(card, 7, newt, 100, 2, inv)
	assert_bool(r["ok"]).is_false()
	assert_str(r["reason"]).is_equal("invalid_slot")
