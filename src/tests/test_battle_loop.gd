## GdUnit4 test suite for ISSUE-005: BattleState + single-fight loop.
##
## Fixtures:
##   test_full_battle_runs_to_completion  — seed=42, 5-card deck, 80HP vs 25HP enemy, asserts
##                                          player_hp > 0 AND enemy_hp == 0, stores golden hash.
##   test_deck_exhaustion_reshuffles      — exhaust deck, verify reshuffle from discard.
##   test_hand_limit_forces_discard       — overflow hand past 10, verify excess discarded.
##
## Golden hash: computed from state.battle_log joined by "\n" and SHA256'd.
## First run writes the hash; subsequent runs assert equality.
extends GdUnitTestSuite

# ---------------------------------------------------------------------------
# Preloads
# ---------------------------------------------------------------------------
const TraitScript       := preload("res://data/trait.gd")
const SlotScript        := preload("res://data/slot.gd")
const CardScript        := preload("res://data/card.gd")
const LoaderScript      := preload("res://data/loader.gd")
const BattleStateScript := preload("res://core/battle_state.gd")
const BattleLoopScript  := preload("res://core/battle_loop.gd")

const TRAITS_PATH    := "res://data/traits.json"
const GOLDEN_PATH    := "res://tests/golden/battle_seed_42.hash"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_that(f).is_not_null()
	var text := f.get_as_text()
	f.close()
	return text


func _load_all_traits() -> Dictionary:
	var loader = LoaderScript.new()
	var traits: Array = loader.load_traits_from_json(_read_file(TRAITS_PATH))
	var by_id: Dictionary = {}
	for t in traits:
		by_id[t.id] = t
	return by_id


## Build a TraitCard with up to 3 traits (pass null for empty slots).
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


## Build a minimal Trait resource.
func _make_trait(tid: String, trigger_int: int, effect_type: String, effect_value: int) -> Resource:
	var t = TraitScript.new()
	t.id              = tid
	t.trigger         = trigger_int
	t.effect_type     = effect_type
	t.effect_value    = effect_value
	t.cooldown_per_turn = -1
	t.axis_timing     = trigger_int
	t.axis_scope      = 0
	t.axis_school     = 0
	t.rarity          = 0
	t.removable       = true
	t.flavor          = ""
	return t


## Build a dummy TraitEnemy-like object using a plain Resource subclass.
## enemy.gd is frozen so we cannot add fields; we set enemy_hp on state directly.
func _make_enemy(id: String) -> Resource:
	var e = preload("res://data/enemy.gd").new()
	e.id     = id
	e.intent = "Attack"
	return e


## Compute SHA256 hex of a string.
func _sha256(text: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(text.to_utf8_buffer())
	var digest: PackedByteArray = ctx.finish()
	var hex: String = ""
	for b in digest:
		hex += "%02x" % b
	return hex


## Build the fixed 5-card test deck: 1 flame_brand card + 4 basic attack cards.
func _make_test_deck(traits: Dictionary) -> Array:
	# Card 0: flame_brand (Damage 4 on OnPlay)
	var flame_card := _make_card(traits["flame_brand"], null, null)

	# Cards 1-4: basic attack cards (no special traits — use a stub OnPlay Damage 2)
	var basic_trait := _make_trait("basic_strike", 0, "Damage", 2)  # OnPlay = 0
	var deck: Array = [flame_card]
	for _i in range(4):
		deck.append(_make_card(basic_trait, null, null))
	return deck


## Run a full battle to completion, returning the final state.
## player_hp=80, enemy_hp=25, intent_damage=5, seed=42.
func _run_full_battle() -> Object:
	var traits := _load_all_traits()
	var deck   := _make_test_deck(traits)
	var enemy  := _make_enemy("test_skeleton")
	var loop   := BattleLoopScript.new()

	var state: Object = loop.start_battle(80, 80, deck, enemy, 42)
	# Override enemy_hp to 25 as per spec (enemy.gd has no hp field)
	state.enemy_hp = 25

	# Run turns until done (cap at 100 to prevent infinite loops in tests)
	var safety: int = 0
	while loop.is_over(state)["ongoing"] and safety < 100:
		safety += 1
		# Play all affordable cards in hand
		var hand_copy: Array = state.hand.duplicate()
		for card in hand_copy:
			if state.energy > 0 and loop.is_over(state)["ongoing"]:
				loop.play_card(state, card, null)
		# End turn if still ongoing
		if loop.is_over(state)["ongoing"]:
			loop.end_turn(state)

	return state


# ---------------------------------------------------------------------------
# Fixture 1: Full battle runs to completion
# ---------------------------------------------------------------------------

func test_full_battle_runs_to_completion() -> void:
	var state: Object = _run_full_battle()
	var result: Dictionary = BattleLoopScript.new().is_over(state)

	# Battle must be over
	assert_bool(result["ongoing"]).is_false()

	# Player must survive (HP > 0)
	assert_int(state.player_hp).is_greater(0)

	# Enemy must be defeated (HP == 0)
	assert_int(state.enemy_hp).is_equal(0)

	# battle_log must be non-empty
	assert_int(state.battle_log.size()).is_greater(0)

	# --- Golden hash ---
	var log_text: String = "\n".join(state.battle_log)
	var computed_hash: String = _sha256(log_text)

	var golden_file := FileAccess.open(GOLDEN_PATH, FileAccess.READ)
	assert_that(golden_file).is_not_null()
	var stored: String = golden_file.get_as_text().strip_edges()
	golden_file.close()

	if stored == "PLACEHOLDER_REPLACE_ON_FIRST_RUN" or stored == "":
		# First run: write the hash as golden
		var wf := FileAccess.open(GOLDEN_PATH, FileAccess.WRITE)
		assert_that(wf).is_not_null()
		wf.store_string(computed_hash)
		wf.close()
		# Pass trivially on first run — hash is now stored
		assert_str(computed_hash).is_not_empty()
	else:
		# Subsequent runs: assert determinism
		assert_str(computed_hash).is_equal(stored)


# ---------------------------------------------------------------------------
# Fixture 2: Deck exhaustion triggers reshuffle
# ---------------------------------------------------------------------------

func test_deck_exhaustion_reshuffles() -> void:
	var traits := _load_all_traits()
	# Use a 3-card deck so it exhausts quickly
	var basic_trait := _make_trait("basic_strike2", 0, "Damage", 2)
	var small_deck: Array = []
	for _i in range(3):
		small_deck.append(_make_card(basic_trait, null, null))

	var enemy  := _make_enemy("weak_enemy")
	var loop   := BattleLoopScript.new()
	var state: Object = loop.start_battle(80, 80, small_deck, enemy, 7)
	state.enemy_hp = 100  # High HP so the battle doesn't end early

	# Play all cards in hand to fill discard
	var hand_copy: Array = state.hand.duplicate()
	for card in hand_copy:
		if state.energy > 0:
			loop.play_card(state, card, null)

	# At this point deck should be exhausted (only 3 cards, all drawn at start)
	# End turn will reshuffle and draw next turn
	var deck_before_reshuffle: int = state.deck.size()
	var discard_before: int = state.discard.size()

	loop.end_turn(state)

	# After end_turn, a new draw occurred. If deck was empty before, reshuffle happened.
	# Verify the log contains a reshuffle entry
	var has_reshuffle: bool = false
	for line in state.battle_log:
		if "reshuffle" in line:
			has_reshuffle = true
			break

	# With only 3 cards and draw_per_turn=5, we must have reshuffled
	assert_bool(has_reshuffle).is_true()

	# After reshuffle+draw, hand should be non-empty
	assert_int(state.hand.size()).is_greater(0)


# ---------------------------------------------------------------------------
# Fixture 3: Hand limit forces discard of excess cards
# ---------------------------------------------------------------------------

func test_hand_limit_forces_discard() -> void:
	var basic_trait := _make_trait("basic_strike3", 0, "Damage", 2)

	# Build a large deck (15 cards) so we can try to fill the hand past 10
	var big_deck: Array = []
	for _i in range(15):
		big_deck.append(_make_card(basic_trait, null, null))

	var enemy  := _make_enemy("tank_enemy")
	var loop   := BattleLoopScript.new()
	var state: Object = loop.start_battle(80, 80, big_deck, enemy, 99)
	state.enemy_hp = 1000  # Won't die during this test

	# Manually stuff the hand to HAND_LIMIT without playing cards
	# Start with the 5 drawn at battle start, then add 5 more directly
	# (simulating a scenario where hand is nearly full before a draw)
	while state.deck.size() > 0 and state.hand.size() < 10:
		state.hand.append(state.deck.pop_back())

	# Hand is now exactly 10; end turn will try to draw 5 more.
	# The loop should discard drawn extras rather than exceed the limit.
	# Reset so we have cards to draw
	assert_int(state.hand.size()).is_equal(10)

	# Directly call _draw_n to trigger overflow logic
	loop._draw_n(state, 5)

	# Hand must not exceed HAND_LIMIT
	assert_int(state.hand.size()).is_less_equal(10)

	# At least some cards should have been discarded (overflow went to discard)
	var has_overflow_log: bool = false
	for line in state.battle_log:
		if "draw_discard_overflow" in line or "discard_to_limit" in line:
			has_overflow_log = true
			break
	assert_bool(has_overflow_log).is_true()
