## ISSUE-016a — Reforge logic (pure, AFK).
## Camp action: pay 100 gold + 1 rare item to swap a card's base.
## Slot[0] is rebuilt from the new base's signature trait. Slots 1/2
## are preserved verbatim. Once-per-card flag `card.reforged` blocks
## re-reforging.
##
## Public API:
##   reforge(card, new_base, signature_trait, gold, rare_items)
##     -> { ok, reason, gold_after, rare_items_after }
##
## `signature_trait` is the trait the caller looked up for `new_base`
## (callers pass a base→signature map, e.g. {"Attack": flame_brand_trait}).
## Keeping the map external preserves "pure logic" — the resolver does
## not reach into JSON.
extends RefCounted

const REFORGE_GOLD_COST: int      = 100
const REFORGE_RARE_ITEM_COST: int = 1


func reforge(card: Resource, new_base: String, signature_trait: Resource,
		gold: int, rare_items: int) -> Dictionary:
	if card == null or signature_trait == null:
		return _fail("invalid_args", gold, rare_items)
	if String(new_base).is_empty():
		return _fail("invalid_base", gold, rare_items)
	if "reforged" in card and bool(card.reforged):
		return _fail("already_reforged", gold, rare_items)
	if gold < REFORGE_GOLD_COST:
		return _fail("insufficient_gold", gold, rare_items)
	if rare_items < REFORGE_RARE_ITEM_COST:
		return _fail("insufficient_rare_items", gold, rare_items)
	if card.slots.size() < 1:
		return _fail("malformed_card", gold, rare_items)

	# Swap base + slot[0] trait. Keep slot[0].locked = true (the Slot setter
	# enforces this by index but we re-call post_load() to be explicit).
	card.base = new_base
	var slot_zero: Resource = card.slots[0]
	slot_zero.trait_ref = signature_trait
	slot_zero.post_load()

	# Mark once-per-card. Card resource may not have the field declared;
	# Resources accept dynamic property setting in GDScript.
	card.set("reforged", true)

	return {
		"ok": true,
		"reason": "",
		"gold_after": gold - REFORGE_GOLD_COST,
		"rare_items_after": rare_items - REFORGE_RARE_ITEM_COST,
	}


func _fail(reason: String, gold: int, rare_items: int) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"gold_after": gold,
		"rare_items_after": rare_items,
	}
