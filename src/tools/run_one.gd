## run_one.gd — headless entry point for a full deterministic run (ISSUE-006).
##
## Usage:
##   godot --headless --display-driver headless --audio-driver Dummy -s tools/run_one.gd -- --seed 42
##
## Prints one CSV row to stdout:
##   seed,outcome,battles_won,hp_left,gold,traits_collected_count
##
## Exit code is always 0 (lost is a valid outcome).
extends SceneTree

const TraitScript   := preload("res://data/trait.gd")
const SlotScript    := preload("res://data/slot.gd")
const CardScript    := preload("res://data/card.gd")
const RunScript     := preload("res://core/run.gd")

# ---------------------------------------------------------------------------
# Deck builder (mirrors test_battle_loop.gd pattern)
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


func _make_sample_deck() -> Array:
	# 5-card deck: 1 flame_brand (Damage 4) + 4 basic strike (Damage 2)
	var flame_trait: Resource = _make_trait("flame_brand", 0, "Damage", 4)   # OnPlay=0
	var basic_trait: Resource = _make_trait("basic_strike", 0, "Damage", 2)  # OnPlay=0

	var deck: Array = []
	deck.append(_make_card(flame_trait, null, null))
	for _i in range(4):
		deck.append(_make_card(basic_trait, null, null))
	return deck


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func _initialize() -> void:
	# Parse --seed N from user args
	var seed_val: int = 42
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for i in range(args.size()):
		if args[i] == "--seed" and i + 1 < args.size():
			var parsed: int = int(args[i + 1])
			if parsed != 0:
				seed_val = parsed
			break

	var run_script: Object = RunScript.new()
	var deck: Array = _make_sample_deck()
	var run_state: Dictionary = run_script.start_run(seed_val, deck, 80)
	run_script.play_full_run(run_state)

	var traits_count: int = run_state["traits_collected"].size()
	var csv_line: String = "%d,%s,%d,%d,%d,%d" % [
		run_state["seed"],
		run_state["outcome"],
		run_state["battles_won"],
		run_state["player_hp"],
		run_state["gold"],
		traits_count,
	]
	print(csv_line)
	quit(0)
