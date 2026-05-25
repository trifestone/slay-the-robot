## GdUnit4 test suite for ISSUE-023: BattleScene end-to-end wiring.
##
## Fixtures:
##   test_setup_renders_initial_state — bind() initializes HP/energy labels,
##                                       hand row populated, enemy bound, end button enabled.
##   test_clicking_card_damages_enemy_and_refreshes — simulate card_clicked,
##                                       verify enemy_hp drops, energy spent, hand shrinks.
##   test_battle_finished_emits_on_victory — drive enough plays to drop enemy
##                                       to 0, assert battle_finished fires with won=true
##                                       and run_state.player_hp synced.
##   test_end_turn_triggers_enemy_intent — pressing End Turn applies intent damage
##                                       and re-fills hand for the next turn.
extends GdUnitTestSuite

const TraitScript        := preload("res://data/trait.gd")
const SlotScript         := preload("res://data/slot.gd")
const CardScript         := preload("res://data/card.gd")
const RunStateResScript  := preload("res://ui/run/run_state_res.gd")
const BattleSceneScene   := preload("res://ui/battle/battle_scene.tscn")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_trait(tid: String, trigger_int: int, etype: String, evalue: int) -> Resource:
	var t: Resource = TraitScript.new()
	t.id                = tid
	t.trigger           = trigger_int
	t.effect_type       = etype
	t.effect_value      = evalue
	t.cooldown_per_turn = -1
	t.axis_timing       = trigger_int
	t.axis_scope        = 0
	t.axis_school       = 0
	t.rarity            = 0
	t.removable         = true
	t.flavor            = ""
	return t


func _make_card(t0: Resource) -> Resource:
	var s0: Resource = SlotScript.new()
	s0.index     = 0
	s0.trait_ref = t0
	s0.locked    = true
	s0.post_load()
	var s1: Resource = SlotScript.new()
	s1.index     = 1
	s1.trait_ref = null
	s1.locked    = false
	s1.post_load()
	var s2: Resource = SlotScript.new()
	s2.index     = 2
	s2.trait_ref = null
	s2.locked    = false
	s2.post_load()
	var card: Resource = CardScript.new()
	card.slots = [s0, s1, s2]
	return card


## Build a 5-card deck of Damage-50 cards. Each one-shots a normal-tier enemy.
func _make_kill_deck() -> Array:
	var heavy: Resource = _make_trait("heavy_strike", 0, "Damage", 50)
	var deck: Array = []
	for _i in range(5):
		deck.append(_make_card(heavy))
	return deck


func _make_run_state(deck: Array, hp: int = 80) -> Resource:
	var rs: Resource = RunStateResScript.from_dict({
		"seed":      1234,
		"player_hp": hp,
		"max_hp":    hp,
		"deck":      deck,
	})
	return rs


## Instantiate scene, add to tree, and await one frame so deferred setup() resolves.
func _spawn_scene(rs: Resource, tier: String = "normal") -> Control:
	var scene: Control = auto_free(BattleSceneScene.instantiate())
	add_child(scene)
	scene.setup(rs, tier, "zh_CN")
	await get_tree().process_frame
	return scene


## Counters used by signal handlers
var _finish_results: Array = []


func before_test() -> void:
	_finish_results = []


func _on_battle_finished(result: Dictionary) -> void:
	_finish_results.append(result)


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_setup_renders_initial_state() -> void:
	var deck: Array = _make_kill_deck()
	var rs: Resource = _make_run_state(deck, 80)
	var scene: Control = await _spawn_scene(rs, "normal")

	var energy_lbl: Label = scene.get_node("EnergyLabel")
	var hp_lbl: Label     = scene.get_node("PlayerHpLabel")
	assert_str(energy_lbl.text).contains("3")
	assert_str(hp_lbl.text).contains("80")

	# Enemy HP equals normal tier baseline (25 from enemy_factory).
	var state: Object = scene._state
	assert_int(state.enemy_hp).is_equal(25)
	assert_int(state.energy).is_equal(3)
	assert_int(state.hand.size()).is_equal(5)

	# End-turn button enabled at start.
	var btn: Button = scene.get_node("EndTurnButton")
	assert_bool(btn.disabled).is_false()


func test_clicking_card_damages_enemy_and_refreshes() -> void:
	var deck: Array = _make_kill_deck()
	var rs: Resource = _make_run_state(deck, 80)
	var scene: Control = await _spawn_scene(rs, "normal")

	var state: Object = scene._state
	var initial_energy: int = state.energy
	var initial_hand: int   = state.hand.size()
	var card: Resource      = state.hand[0]

	scene._on_card_clicked(card)
	await get_tree().process_frame

	# Heavy strike deals 50 → enemy (25 HP) drops to 0, battle ends.
	assert_int(state.enemy_hp).is_equal(0)
	assert_int(state.energy).is_equal(initial_energy - 1)
	assert_int(state.hand.size()).is_equal(initial_hand - 1)


func test_battle_finished_emits_on_victory() -> void:
	var deck: Array = _make_kill_deck()
	var rs: Resource = _make_run_state(deck, 80)
	var scene: Control = await _spawn_scene(rs, "normal")
	scene.battle_finished.connect(_on_battle_finished)
	# Skip the summary-readability hold so the suite stays fast; the live
	# scene uses ~2.6s but tests only await a single process_frame.
	scene._finalize_delay_seconds = 0.0

	var card: Resource = scene._state.hand[0]
	scene._on_card_clicked(card)
	await get_tree().process_frame

	# battle_finished should have fired exactly once with won=true.
	assert_int(_finish_results.size()).is_equal(1)
	assert_bool(bool(_finish_results[0].get("won", false))).is_true()
	assert_int(int(_finish_results[0].get("hp_left", -1))).is_equal(scene._state.player_hp)
	assert_int(rs.player_hp).is_equal(scene._state.player_hp)
	# End-turn button disabled after finish.
	var btn: Button = scene.get_node("EndTurnButton")
	assert_bool(btn.disabled).is_true()


func test_end_turn_triggers_enemy_intent() -> void:
	# Deck that can't kill in one click → end turn → enemy attacks for 5.
	var weak: Resource = _make_trait("tap", 0, "Damage", 1)
	var deck: Array = []
	for _i in range(5):
		deck.append(_make_card(weak))
	var rs: Resource = _make_run_state(deck, 80)
	var scene: Control = await _spawn_scene(rs, "normal")

	var hp_before: int = scene._state.player_hp
	scene._on_end_turn_pressed()
	await get_tree().process_frame

	# Normal tier intent_damage = 5 (enemy_factory NORMAL_INTENT).
	assert_int(scene._state.player_hp).is_equal(hp_before - 5)
	# New turn → energy refilled, hand redrawn.
	assert_int(scene._state.energy).is_equal(3)
	assert_int(scene._state.hand.size()).is_greater(0)
