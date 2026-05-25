## ISSUE-015a — Shop transactions (pure logic, AFK).
## Three operations:
##   buy_card(deck, card_id, cost, gold)         → append card_id to deck
##   buy_trait(inventory, trait_id, cost, gold)  → push trait_id to inventory
##                                                 (blocks when inventory full)
##   buy_heal(player_hp, max_hp, cost, gold)     → heal 30% of max_hp,
##                                                 capped at max_hp
##
## Card / trait IDs and costs are caller-supplied — the shop scene picks 3
## random cards (50/80/140g for Common/Uncommon/Rare) and 3 random traits
## (40/70/120g) at session start, then calls into this resolver per click.
## Heal costs 50g and restores 30% of max_hp (PRD §4.8).
##
## All operations return a Dictionary:
##   {ok, reason, gold_after, ...post_state_fields}
extends RefCounted

const HEAL_COST: int       = 50
const HEAL_PERCENT: float  = 0.30
const INVENTORY_CAP: int   = 5  # mirrors inventory_manager.CAPACITY


func buy_card(deck: Array, card_id: String, cost: int, gold: int) -> Dictionary:
	if deck == null:
		return _fail_card("invalid_args", gold, deck)
	if card_id.is_empty():
		return _fail_card("invalid_card", gold, deck)
	if cost < 0:
		return _fail_card("invalid_cost", gold, deck)
	if gold < cost:
		return _fail_card("insufficient_gold", gold, deck)

	deck.append(card_id)
	return {
		"ok": true,
		"reason": "",
		"gold_after": gold - cost,
		"deck_after": deck,
	}


func buy_trait(inventory: Array, trait_id: String, cost: int, gold: int) -> Dictionary:
	if inventory == null:
		return _fail_trait("invalid_args", gold, inventory)
	if trait_id.is_empty():
		return _fail_trait("invalid_trait", gold, inventory)
	if cost < 0:
		return _fail_trait("invalid_cost", gold, inventory)
	if gold < cost:
		return _fail_trait("insufficient_gold", gold, inventory)
	if inventory.size() >= INVENTORY_CAP:
		return _fail_trait("inventory_full", gold, inventory)

	inventory.append(trait_id)
	return {
		"ok": true,
		"reason": "",
		"gold_after": gold - cost,
		"inventory_after": inventory,
	}


func buy_heal(player_hp: int, max_hp: int, gold: int) -> Dictionary:
	if max_hp <= 0:
		return _fail_heal("invalid_max_hp", gold, player_hp)
	if gold < HEAL_COST:
		return _fail_heal("insufficient_gold", gold, player_hp)
	if player_hp >= max_hp:
		return _fail_heal("already_full_hp", gold, player_hp)

	var amount: int = int(ceil(float(max_hp) * HEAL_PERCENT))
	var new_hp: int = mini(player_hp + amount, max_hp)
	return {
		"ok": true,
		"reason": "",
		"gold_after": gold - HEAL_COST,
		"player_hp_after": new_hp,
		"healed": new_hp - player_hp,
	}


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _fail_card(reason: String, gold: int, deck: Array) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"gold_after": gold,
		"deck_after": deck,
	}


func _fail_trait(reason: String, gold: int, inventory: Array) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"gold_after": gold,
		"inventory_after": inventory,
	}


func _fail_heal(reason: String, gold: int, player_hp: int) -> Dictionary:
	return {
		"ok": false,
		"reason": reason,
		"gold_after": gold,
		"player_hp_after": player_hp,
		"healed": 0,
	}
