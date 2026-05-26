## Regression tests for the three reported combat bugs:
##   1. Block/Draw effects were ignored — only Damage was applied.
##   2. HealSelfPercent had no effect on player HP.
##   3. Enemy HP sync could cause premature death due to sync_primary_hp_into_entry
##      overwriting entry["hp"] inside _apply_damage_to_primary.
extends GdUnitTestSuite

const TraitScript       := preload("res://data/trait.gd")
const SlotScript        := preload("res://data/slot.gd")
const CardScript        := preload("res://data/card.gd")
const BattleStateScript := preload("res://core/battle_state.gd")
const BattleLoopScript  := preload("res://core/battle_loop.gd")


func _make_trait(tid: String, trigger_int: int, effect_type: String, effect_value: int) -> Resource:
	var t = TraitScript.new()
	t.id = tid
	t.trigger = trigger_int
	t.effect_type = effect_type
	t.effect_value = effect_value
	t.cooldown_per_turn = -1
	t.axis_timing = trigger_int
	t.axis_scope = 0
	t.axis_school = 0
	t.rarity = 0
	t.removable = true
	t.flavor = ""
	return t


func _make_card(t0: Resource, t1, t2) -> Resource:
	var s0 = SlotScript.new()
	s0.index = 0
	s0.trait_ref = t0
	s0.locked = true
	s0.post_load()
	var s1 = SlotScript.new()
	s1.index = 1
	s1.trait_ref = t1
	s1.locked = false
	s1.post_load()
	var s2 = SlotScript.new()
	s2.index = 2
	s2.trait_ref = t2
	s2.locked = false
	s2.post_load()
	var card = CardScript.new()
	card.slots = [s0, s1, s2]
	return card


func _make_enemy(id: String) -> Resource:
	var e = preload("res://data/enemy.gd").new()
	e.id = id
	e.intent = "Attack"
	return e


# ---------------------------------------------------------------------------
# Bug 1: Block effect actually grants player block (was completely ignored)
# ---------------------------------------------------------------------------

func test_block_on_play_increases_player_block() -> void:
	var loop := BattleLoopScript.new()
	var block_trait := _make_trait("bone_shield", 0, "Block", 5)  # OnPlay, Block 5
	var deck: Array = [_make_card(block_trait, null, null)]
	var enemy := _make_enemy("dummy")
	var state: Object = loop.start_battle(80, 80, deck, enemy, 1)
	state.enemy_hp = 100

	loop.play_card(state, deck[0], null)
	assert_int(state.player_block).is_equal(5)


func test_draw_on_play_draws_extra_cards() -> void:
	var loop := BattleLoopScript.new()
	var draw_trait := _make_trait("lunar_tide", 0, "Draw", 1)  # OnPlay, Draw 1
	var draw_card := _make_card(draw_trait, null, null)
	var filler := _make_trait("filler", 0, "Damage", 1)
	var deck: Array = [
		draw_card,
		_make_card(filler, null, null),
		_make_card(filler, null, null),
		_make_card(filler, null, null),
	]
	var enemy := _make_enemy("dummy")
	var state: Object = loop.start_battle(80, 80, deck, enemy, 1)
	state.enemy_hp = 100

	# Find the draw card in hand (deck was shuffled)
	var draw_card_in_hand: Resource = null
	for c in state.hand:
		if c.has_trait_id("lunar_tide"):
			draw_card_in_hand = c
			break
	assert_that(draw_card_in_hand).is_not_null()

	var hand_before: int = state.hand.size()
	loop.play_card(state, draw_card_in_hand, null)
	assert_int(state.hand.size()).is_equal(hand_before - 1 + 1)  # played 1, drew 1


# ---------------------------------------------------------------------------
# Bug 2: HealSelfPercent actually restores HP (was completely ignored)
# ---------------------------------------------------------------------------

func test_heal_self_percent_restores_hp() -> void:
	var loop := BattleLoopScript.new()
	var heal_trait := _make_trait("purify_light", 0, "HealSelfPercent", 6)  # OnPlay, heal 6%
	var deck: Array = [_make_card(heal_trait, null, null)]
	var enemy := _make_enemy("dummy")
	var state: Object = loop.start_battle(80, 80, deck, enemy, 1)
	state.enemy_hp = 100
	state.player_hp = 50  # damaged

	loop.play_card(state, deck[0], null)
	var expected_heal: int = max(1, int(80 * 6 / 100.0))  # 4 HP
	assert_int(state.player_hp).is_equal(50 + expected_heal)


func test_heal_fixed_amount_restores_hp() -> void:
	var loop := BattleLoopScript.new()
	var heal_trait := _make_trait("heal_wound", 0, "Heal", 2)  # OnPlay, heal 2
	var deck: Array = [_make_card(heal_trait, null, null)]
	var enemy := _make_enemy("dummy")
	var state: Object = loop.start_battle(80, 80, deck, enemy, 1)
	state.enemy_hp = 100
	state.player_hp = 50

	loop.play_card(state, deck[0], null)
	assert_int(state.player_hp).is_equal(52)


# ---------------------------------------------------------------------------
# Bug 3: Enemy does not die before HP reaches zero
# ---------------------------------------------------------------------------

func test_enemy_survives_when_damage_less_than_hp() -> void:
	var loop := BattleLoopScript.new()
	var dmg_trait := _make_trait("steel_fist", 0, "Damage", 5)  # OnPlay, Damage 5
	var deck: Array = [_make_card(dmg_trait, null, null)]
	var enemy := _make_enemy("dummy")
	var state: Object = loop.start_battle(80, 80, deck, enemy, 1)
	# Set both enemy_hp and the authoritative entry["hp"] to stay in sync
	state.enemy_hp = 10
	state.enemies[0]["hp"] = 10

	loop.play_card(state, deck[0], null)
	assert_int(state.enemy_hp).is_equal(5)  # 10 - 5 = 5, not dead
	assert_bool(loop.is_over(state)["ongoing"]).is_true()


func test_enemy_dies_exactly_at_zero_hp() -> void:
	var loop := BattleLoopScript.new()
	var dmg_trait := _make_trait("steel_fist", 0, "Damage", 10)  # OnPlay, Damage 10
	var deck: Array = [_make_card(dmg_trait, null, null)]
	var enemy := _make_enemy("dummy")
	var state: Object = loop.start_battle(80, 80, deck, enemy, 1)
	state.enemy_hp = 10
	state.enemies[0]["hp"] = 10

	loop.play_card(state, deck[0], null)
	assert_int(state.enemy_hp).is_equal(0)
	assert_bool(loop.is_over(state)["won"]).is_true()


func test_multi_enemy_sync_no_premature_death() -> void:
	var loop := BattleLoopScript.new()
	var dmg_trait := _make_trait("steel_fist", 0, "Damage", 3)
	var card := _make_card(dmg_trait, null, null)
	var deck: Array = [card, card]  # 2 copies so we can play twice
	var enemy := _make_enemy("dummy")
	var state: Object = loop.start_battle(80, 80, deck, enemy, 1)

	# Set up 2 enemies with explicit HP
	state.enemies = [
		{"enemy": enemy, "hp": 5, "max_hp": 5, "intent_damage": 3},
		{"enemy": enemy, "hp": 8, "max_hp": 8, "intent_damage": 3},
	]
	state.primary_enemy_idx = 0
	state.sync_primary_enemy()

	# Deal 3 damage to enemy 0 (HP 5 -> 2, still alive)
	var card0: Resource = state.hand[0]
	loop.play_card(state, card0, null)
	assert_int(state.enemies[0]["hp"]).is_equal(2)
	assert_bool(loop.is_over(state)["ongoing"]).is_true()

	# Deal 3 more damage to enemy 0 (HP 2 -> 0, dies)
	var card1: Resource = state.hand[0]
	loop.play_card(state, card1, null)
	assert_int(state.enemies[0]["hp"]).is_equal(0)
	assert_bool(loop.is_over(state)["ongoing"]).is_true()  # enemy 1 still alive


func test_player_block_absorbs_enemy_attack() -> void:
	var loop := BattleLoopScript.new()
	var block_trait := _make_trait("flame_ward", 6, "Block", 3)  # EndTurn, Block 3
	var deck: Array = [_make_card(block_trait, null, null)]
	var enemy := _make_enemy("dummy")
	var state: Object = loop.start_battle(80, 80, deck, enemy, 1)
	state.enemy_hp = 100
	state.enemies[0]["intent_damage"] = 5

	# End turn triggers EndTurn block, enemy attacks, block absorbs 3 of 5 damage
	loop.end_turn(state)
	# Block is fully consumed during enemy attack (3 block vs 5 dmg); unused block carries over turns now
	assert_int(state.player_hp).is_equal(78)  # 80 - (5-3) = 78
	assert_int(state.player_block).is_equal(0)  # all 3 block consumed by the 5-dmg hit
