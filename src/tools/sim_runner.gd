## sim_runner.gd — Core simulation loop for ISSUE-019 headless 1k-run harness.
##
## Runbook:
##   1. Instantiate SimRunner.new()
##   2. Call run_simulation(n_runs, seed_base, out_path)
##   3. CSV written to out_path; summary written next to it as *_summary.txt
##   4. Returns {csv_path, summary_path, win_count, total_runs, rows}
##
## Auto-play policy: greedy "highest-damage first" — delegated entirely to
## run.gd's play_full_run which already runs the greedy loop in play_battle.
##
## NO class_name declaration (Slay-The-Robot collision avoidance).
## extends RefCounted so GdUnit4 tests can instantiate directly.
extends RefCounted

const RunScript   := preload("res://core/run.gd")
const TraitScript := preload("res://data/trait.gd")
const SlotScript  := preload("res://data/slot.gd")
const CardScript  := preload("res://data/card.gd")

const CSV_HEADER := "run_id,seed,outcome,battles_won,hp_left,gold,traits_collected,reactions_triggered,total_turns"

# ---------------------------------------------------------------------------
# Deck builder — same 5-card fixture used in all existing test suites
# ---------------------------------------------------------------------------

func _make_trait(tid: String, trigger_int: int, etype: String, evalue: int) -> Resource:
	var t: Resource = TraitScript.new()
	t.id               = tid
	t.trigger          = trigger_int
	t.effect_type      = etype
	t.effect_value     = evalue
	t.cooldown_per_turn = -1
	t.axis_timing      = trigger_int
	t.axis_scope       = 0
	t.axis_school      = 0
	t.rarity           = 0
	t.removable        = true
	t.flavor           = ""
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
	## Build canonical 5-card starting deck: 1 flame_brand (Damage 4) + 4 basic strike (Damage 2).
	var flame_trait: Resource = _make_trait("flame_brand", 0, "Damage", 4)
	var basic_trait: Resource = _make_trait("basic_strike", 0, "Damage", 2)
	var deck: Array = []
	deck.append(_make_card(flame_trait, null, null))
	for _i in range(4):
		deck.append(_make_card(basic_trait, null, null))
	return deck


# ---------------------------------------------------------------------------
# Statistics helpers
# ---------------------------------------------------------------------------

func _mean(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var s: float = 0.0
	for v in values:
		s += float(v)
	return s / float(values.size())


func _stddev(values: Array) -> float:
	if values.size() < 2:
		return 0.0
	var m: float = _mean(values)
	var variance: float = 0.0
	for v in values:
		var diff: float = float(v) - m
		variance += diff * diff
	variance /= float(values.size())
	return sqrt(variance)


# ---------------------------------------------------------------------------
# CSV formatting
# ---------------------------------------------------------------------------

func _row_to_csv(row: Dictionary) -> String:
	return "%d,%d,%s,%d,%d,%d,%d,%d,%d" % [
		row["run_id"],
		row["seed"],
		row["outcome"],
		row["battles_won"],
		row["hp_left"],
		row["gold"],
		row["traits_collected"],
		row["reactions_triggered"],
		row["total_turns"],
	]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Run n_runs simulations starting at seed_base. Writes CSV to out_path and
## a summary to out_path.replace(".csv", "_summary.txt"). Returns result dict.
func run_simulation(n_runs: int, seed_base: int, out_path: String) -> Dictionary:
	var rows: Array        = []
	var win_count: int     = 0
	var hp_list: Array     = []
	var gold_list: Array   = []
	var turns_list: Array  = []
	# per-trait pick_count accumulated inline (no second pass)
	var trait_counts: Dictionary = {}

	for i in range(n_runs):
		var run: Object       = RunScript.new()
		var deck: Array       = _make_sample_deck()
		var state: Dictionary = run.start_run(seed_base + i, deck, 80)
		run.play_full_run(state)

		# total_turns proxy: battles_won (one battle == at least one turn)
		var total_turns: int = state["battles_won"]

		# TODO(ISSUE-021): replace 0 with state["reaction_fire_log"].size() once
		# reaction_fire_log is wired into RunState (ISSUE-021 owns that change).
		var reactions_triggered: int = 0

		var traits_list: Array = state["traits_collected"]
		for tid in traits_list:
			if not trait_counts.has(tid):
				trait_counts[tid] = 0
			trait_counts[tid] += 1

		var row: Dictionary = {
			"run_id":             i,
			"seed":               seed_base + i,
			"outcome":            state["outcome"],
			"battles_won":        state["battles_won"],
			"hp_left":            state["player_hp"],
			"gold":               state["gold"],
			"traits_collected":   traits_list.size(),
			"reactions_triggered": reactions_triggered,
			"total_turns":        total_turns,
		}
		rows.append(row)

		if state["outcome"] == "won":
			win_count += 1
		hp_list.append(state["player_hp"])
		gold_list.append(state["gold"])
		turns_list.append(total_turns)

	# --- Build CSV content ---
	var csv_lines: PackedStringArray = PackedStringArray()
	csv_lines.append(CSV_HEADER)
	for row in rows:
		csv_lines.append(_row_to_csv(row))
	var csv_content: String = "\n".join(csv_lines) + "\n"

	# --- Write CSV ---
	var csv_file := FileAccess.open(out_path, FileAccess.WRITE)
	assert(csv_file != null, "sim_runner: cannot write CSV to " + out_path)
	csv_file.store_string(csv_content)
	csv_file.close()

	# --- Build summary ---
	var win_rate: float = 0.0
	if n_runs > 0:
		win_rate = float(win_count) / float(n_runs) * 100.0

	var summary_path: String = out_path.replace(".csv", "_summary.txt")
	var sum_lines: PackedStringArray = PackedStringArray()
	sum_lines.append("=== Simulation Summary ===")
	sum_lines.append("runs:      %d" % n_runs)
	sum_lines.append("wins:      %d" % win_count)
	sum_lines.append("win_rate:  %.2f%%" % win_rate)
	sum_lines.append("")
	sum_lines.append("--- per-trait pick_count ---")
	if trait_counts.is_empty():
		sum_lines.append("  (no traits collected)")
	else:
		var sorted_traits: Array = trait_counts.keys()
		sorted_traits.sort()
		for tid in sorted_traits:
			sum_lines.append("  %s: %d" % [tid, trait_counts[tid]])
	sum_lines.append("")
	# TODO(ISSUE-021): replace stub below with real per-reaction fire_count/run
	# once run_state["reaction_fire_log"] is available.
	sum_lines.append("--- per-reaction fire_count/run ---")
	sum_lines.append("  (reaction_fire_log not yet wired — all counts are 0)")
	sum_lines.append("")
	sum_lines.append("--- hp_left ---")
	sum_lines.append("  mean:   %.2f" % _mean(hp_list))
	sum_lines.append("  stddev: %.2f" % _stddev(hp_list))
	sum_lines.append("")
	sum_lines.append("--- gold ---")
	sum_lines.append("  mean:   %.2f" % _mean(gold_list))
	sum_lines.append("  stddev: %.2f" % _stddev(gold_list))
	sum_lines.append("")
	sum_lines.append("--- total_turns ---")
	sum_lines.append("  mean:   %.2f" % _mean(turns_list))
	sum_lines.append("  stddev: %.2f" % _stddev(turns_list))

	# --- Write summary ---
	var sum_file := FileAccess.open(summary_path, FileAccess.WRITE)
	assert(sum_file != null, "sim_runner: cannot write summary to " + summary_path)
	sum_file.store_string("\n".join(sum_lines) + "\n")
	sum_file.close()

	return {
		"csv_path":     out_path,
		"summary_path": summary_path,
		"win_count":    win_count,
		"total_runs":   n_runs,
		"rows":         rows,
	}
