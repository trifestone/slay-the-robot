## sim.gd — Headless 1k-run simulation entry point for ISSUE-019.
##
## Runbook:
##   godot --headless --path . -s tools/sim.gd --runs 1000 --seed-base 1 --out user://sim_results.csv
##
## CLI args (all optional):
##   --runs N        Number of runs to simulate (default: 1000)
##   --seed-base S   Base seed; run i uses seed S+i (default: 1)
##   --out path      Output CSV path (default: res://tools/sim_results.csv)
##
## Outputs:
##   <out>                 — CSV with one row per run
##   <out stem>_summary.txt — Aggregated win-rate, trait counts, hp/gold/turns stats
##
## Exit code: 0 always (sim failure is a valid outcome, not an error).
##
## Auto-play policy: greedy "highest-damage first" — fully delegated to
## run.gd's play_battle which already implements the greedy loop.
extends SceneTree

const SimRunnerScript := preload("res://tools/sim_runner.gd")

func _initialize() -> void:
	var n_runs: int      = 1000
	var seed_base: int   = 1
	var out_path: String = "res://tools/sim_results.csv"

	# Parse --runs / --seed-base / --out from user args (after "--")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		match args[i]:
			"--runs":
				if i + 1 < args.size():
					var v: int = int(args[i + 1])
					if v > 0:
						n_runs = v
					i += 1
			"--seed-base":
				if i + 1 < args.size():
					var v: int = int(args[i + 1])
					if v != 0:
						seed_base = v
					i += 1
			"--out":
				if i + 1 < args.size():
					out_path = args[i + 1]
					i += 1
		i += 1

	print("sim.gd: starting %d runs, seed_base=%d, out=%s" % [n_runs, seed_base, out_path])

	var runner: Object = SimRunnerScript.new()
	var result: Dictionary = runner.run_simulation(n_runs, seed_base, out_path)

	var win_rate: float = 0.0
	if result["total_runs"] > 0:
		win_rate = float(result["win_count"]) / float(result["total_runs"]) * 100.0

	print("sim.gd: done. wins=%d/%d (%.1f%%)  csv=%s  summary=%s" % [
		result["win_count"],
		result["total_runs"],
		win_rate,
		result["csv_path"],
		result["summary_path"],
	])

	quit(0)
