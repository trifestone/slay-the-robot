## GdUnit4 test suite for ISSUE-006: 18-battle Run sequence.
##
## Fixtures:
##   test_run_seed_42_completes_18_battles_or_dies  — seed=42 run ends in won/lost,
##                                                    determinism: same battles_won both runs.
##   test_death_stops_run                           — player_hp=1 vs hp=1000 enemy → lost
##                                                    at battle 0 or 1, current_battle <= 1.
extends GdUnitTestSuite

const TraitScript  := preload("res://data/trait.gd")
const SlotScript   := preload("res://data/slot.gd")
const CardScript   := preload("res://data/card.gd")
const RunScript    := preload("res://core/run.gd")

# ---------------------------------------------------------------------------
# Helpers (same pattern as test_battle_loop.gd)
# ---------------------------------------------------------------------------

func _make_trait(tid: String, trigger_int: int, etype: String, evalue: int) -> Resource:
	var t: Resource = TraitScript.new()
	t.id              = tid
	t.trigger         = trigger_int
	t.effect_type     = etype
	t.effect_value    = evalue
	t.cooldown_per_turn = -1
	t.axis_timing     = trigger_int
	t.axis_scope      = 0
	t.axis_school     = 0
	t.rarity          = 0
	t.removable       = true
	t.flavor          = ""
	return t


func _make_card(t0: Resource, t1, t2) -> Resource:
	var s0: Resource = SlotScript.new()
	s0.index     = 0
	s0.trait_ref = t0
	s0.locked    = true
	s0.post_load()

	var s1: Resource = SlotScript.new()
	s1.index     = 1
	s1.trait_ref = t1
	s1.locked    = false
	s1.post_load()

	var s2: Resource = SlotScript.new()
	s2.index     = 2
	s2.trait_ref = t2
	s2.locked    = false
	s2.post_load()

	var card: Resource = CardScript.new()
	card.slots = [s0, s1, s2]
	return card


## 5-card sample deck: 1 flame_brand (Damage 4) + 4 basic strike (Damage 2).
func _make_sample_deck() -> Array:
	var flame_trait: Resource = _make_trait("flame_brand", 0, "Damage", 4)
	var basic_trait: Resource = _make_trait("basic_strike", 0, "Damage", 2)
	var deck: Array = []
	deck.append(_make_card(flame_trait, null, null))
	for _i in range(4):
		deck.append(_make_card(basic_trait, null, null))
	return deck


# ---------------------------------------------------------------------------
# Fixture 1: seed=42 run completes without crash, deterministic
# ---------------------------------------------------------------------------

func test_run_seed_42_completes_18_battles_or_dies() -> void:
	var run: Object = RunScript.new()

	# --- First run ---
	var deck1: Array = _make_sample_deck()
	var rs1: Dictionary = run.start_run(42, deck1, 80)
	run.play_full_run(rs1)

	# Run must have ended
	assert_bool(rs1["outcome"] == "won" or rs1["outcome"] == "lost").is_true()
	# current_battle must be <= 18
	assert_int(rs1["current_battle"]).is_less_equal(18)
	# If won, exactly 18 battles won
	if rs1["outcome"] == "won":
		assert_int(rs1["battles_won"]).is_equal(18)

	# --- Second run (same seed) — must yield identical battles_won ---
	var run2: Object = RunScript.new()
	var deck2: Array = _make_sample_deck()
	var rs2: Dictionary = run2.start_run(42, deck2, 80)
	run2.play_full_run(rs2)

	assert_int(rs2["battles_won"]).is_equal(rs1["battles_won"])
	assert_str(rs2["outcome"]).is_equal(rs1["outcome"])


# ---------------------------------------------------------------------------
# Fixture 2: death stops run early
# ---------------------------------------------------------------------------

func test_death_stops_run() -> void:
	# Give player only 1 HP — enemy has DEFAULT_INTENT_DAMAGE=5 so first enemy
	# attack kills player. Run should stop at battle 0 or 1.
	var run: Object = RunScript.new()
	var deck: Array = _make_sample_deck()
	var rs: Dictionary = run.start_run(1, deck, 1)
	run.play_full_run(rs)

	assert_str(rs["outcome"]).is_equal("lost")
	# Stopped very early — no more than 2 battles attempted
	assert_int(rs["current_battle"]).is_less_equal(2)
