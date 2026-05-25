## ISSUE-013a — Camp transactions (pure logic, AFK).
## Mount / dismantle trait operations; the camp UI scene tree consumes
## these and surfaces toasts. State surface kept tiny by intent —
## gold + dismantle_points + Inventory + the target Card are the only
## inputs, and every operation returns a result Dictionary so the UI
## can render the appropriate toast/sfx without re-checking the rules.
##
## Public API:
##   mount_trait_to_slot(card, slot_idx, trait, gold, dismantle_points, inventory)
##     -> {ok, reason, gold_after, dismantle_after, replaced_trait}
##   dismantle_slot(card, slot_idx, gold, dismantle_points, inventory)
##     -> {ok, reason, gold_after, dismantle_after}
##
## Acceptance gates (PRD §3 US-06/07/08, ISSUE-013):
##   1. mount on empty slot is FREE
##   2. mount that replaces an existing trait costs 30 gold
##   3. dismantle costs 50 gold + 1 dismantle point and returns trait to inventory
##   4. slot[0] (base) is immutable — cannot mount, cannot dismantle
##   5. full inventory blocks dismantle (toast)
##   6. duplicate-trait on same card is blocked (PRD A2 §9.3 rule 1)
extends RefCounted

const REPLACE_COST: int       = 30
const DISMANTLE_GOLD_COST: int = 50
const DISMANTLE_POINT_COST: int = 1


func mount_trait_to_slot(card: Resource, slot_idx: int, trait_to_mount: Resource,
		gold: int, dismantle_points: int, inventory: Resource) -> Dictionary:
	if card == null or trait_to_mount == null or inventory == null:
		return _fail("invalid_args", gold, dismantle_points)
	if slot_idx < 0 or slot_idx >= card.slots.size():
		return _fail("invalid_slot", gold, dismantle_points)
	if slot_idx == 0:
		return _fail("slot_locked", gold, dismantle_points)

	# Duplicate check — a card may not have two copies of the same trait id
	# (PRD A2 §9.3 rule 1). The slot we're targeting is allowed to already
	# contain the same id only if we're replacing it with a *different* id;
	# block when ANY slot already holds this id.
	var slot: Resource = card.slots[slot_idx]
	var existing: Resource = slot.trait_ref
	for s in card.slots:
		if s.trait_ref != null and s.trait_ref.id == trait_to_mount.id:
			# Allow no-op if it's literally the same slot AND same trait, but
			# that would be a free mount over itself which is meaningless;
			# we still treat duplicate-on-same-card as a block.
			return _fail("duplicate_trait", gold, dismantle_points)

	var cost: int = 0
	var replaced: Resource = null
	if existing != null:
		cost = REPLACE_COST
		if gold < cost:
			return _fail("insufficient_gold", gold, dismantle_points)
		replaced = existing

	# Remove the trait being mounted from inventory (the UI is expected to
	# only feed traits that came from the inventory; we still verify).
	var taken: Resource = inventory.remove_trait_by_id(trait_to_mount.id)
	if taken == null:
		return _fail("trait_not_in_inventory", gold, dismantle_points)

	slot.trait_ref = trait_to_mount
	gold -= cost

	return {
		"ok": true,
		"reason": "",
		"gold_after": gold,
		"dismantle_after": dismantle_points,
		"replaced_trait": replaced,
	}


func dismantle_slot(card: Resource, slot_idx: int,
		gold: int, dismantle_points: int, inventory: Resource) -> Dictionary:
	if card == null or inventory == null:
		return _fail("invalid_args", gold, dismantle_points)
	if slot_idx < 0 or slot_idx >= card.slots.size():
		return _fail("invalid_slot", gold, dismantle_points)
	if slot_idx == 0:
		return _fail("slot_locked", gold, dismantle_points)

	var slot: Resource = card.slots[slot_idx]
	var existing: Resource = slot.trait_ref
	if existing == null:
		return _fail("slot_empty", gold, dismantle_points)
	if not bool(existing.removable):
		return _fail("trait_not_removable", gold, dismantle_points)
	if gold < DISMANTLE_GOLD_COST:
		return _fail("insufficient_gold", gold, dismantle_points)
	if dismantle_points < DISMANTLE_POINT_COST:
		return _fail("insufficient_dismantle_points", gold, dismantle_points)
	if not inventory.has_space():
		return _fail("inventory_full", gold, dismantle_points)

	slot.trait_ref = null
	inventory.add_trait(existing)

	return {
		"ok": true,
		"reason": "",
		"gold_after": gold - DISMANTLE_GOLD_COST,
		"dismantle_after": dismantle_points - DISMANTLE_POINT_COST,
	}


func _fail(reason: String, gold: int, dismantle_points: int) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"gold_after": gold,
		"dismantle_after": dismantle_points,
	}
