## sim_diff.gd — Baseline-diff harness for ISSUE-019.
##
## Runbook:
##   godot --headless --path . -s tools/sim_diff.gd \
##         --actual user://sim_results.csv \
##         --baseline prototype/sim_results.csv
##
## CLI args:
##   --actual   <path>   Path to the new simulation CSV (required)
##   --baseline <path>   Path to the baseline CSV (default: res://prototype/sim_results.csv)
##   --out      <path>   Where to write the diff report (default: res://tools/sim_diff.txt)
##
## Diff rules:
##   1. win-rate within ±5% of baseline win-rate
##      (prototype baseline 59.1% → acceptable band 54.1–64.1%)
##   2. per-reaction fire_count/run within 0.3–3.0 band
##      (skipped with a warning when reaction count == 0 in both actual and baseline)
##
## Exit codes:
##   0 — all checks pass
##   2 — one or more checks breached (sim_diff.txt written with offending details)
extends SceneTree

# ---------------------------------------------------------------------------
# CSV parsing helpers
# ---------------------------------------------------------------------------

## Parse CSV into Array of Dictionaries keyed by header columns.
func _parse_csv(path: String) -> Array:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return []
	var text: String = file.get_as_text()
	file.close()

	var lines: PackedStringArray = text.split("\n")
	var result: Array = []
	var headers: PackedStringArray = PackedStringArray()

	for line_idx in range(lines.size()):
		var line: String = lines[line_idx].strip_edges()
		# Skip blank lines and comment lines starting with #
		if line.is_empty() or line.begins_with("#"):
			continue
		var cols: PackedStringArray = line.split(",")
		if headers.is_empty():
			headers = cols
			continue
		if cols.size() < headers.size():
			continue
		var row: Dictionary = {}
		for col_idx in range(headers.size()):
			row[headers[col_idx].strip_edges()] = cols[col_idx].strip_edges()
		result.append(row)

	return result


## Compute win-rate (0.0–100.0) from parsed rows.
func _win_rate(rows: Array) -> float:
	if rows.is_empty():
		return 0.0
	var wins: int = 0
	for row in rows:
		if row.get("outcome", "") == "won":
			wins += 1
	return float(wins) / float(rows.size()) * 100.0


## Compute mean reactions_triggered per run.
func _mean_reactions(rows: Array) -> float:
	if rows.is_empty():
		return 0.0
	var total: float = 0.0
	for row in rows:
		total += float(row.get("reactions_triggered", "0"))
	return total / float(rows.size())


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

func _initialize() -> void:
	var actual_path:   String = ""
	var baseline_path: String = "res://prototype/sim_results.csv"
	var out_path:      String = "res://tools/sim_diff.txt"

	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = 0
	while i < args.size():
		match args[i]:
			"--actual":
				if i + 1 < args.size():
					actual_path = args[i + 1]
					i += 1
			"--baseline":
				if i + 1 < args.size():
					baseline_path = args[i + 1]
					i += 1
			"--out":
				if i + 1 < args.size():
					out_path = args[i + 1]
					i += 1
		i += 1

	if actual_path.is_empty():
		push_error("sim_diff.gd: --actual <path> is required")
		quit(2)
		return

	var actual_rows:   Array = _parse_csv(actual_path)
	var baseline_rows: Array = _parse_csv(baseline_path)

	if actual_rows.is_empty():
		push_error("sim_diff.gd: actual CSV is empty or unreadable: " + actual_path)
		quit(2)
		return
	if baseline_rows.is_empty():
		push_error("sim_diff.gd: baseline CSV is empty or unreadable: " + baseline_path)
		quit(2)
		return

	var breaches: Array = []

	# --- Rule 1: win-rate within ±5% of baseline ---
	var actual_wr:   float = _win_rate(actual_rows)
	var baseline_wr: float = _win_rate(baseline_rows)
	var wr_diff:     float = abs(actual_wr - baseline_wr)
	if wr_diff > 5.0:
		breaches.append("WIN_RATE_BREACH: actual=%.2f%% baseline=%.2f%% diff=%.2f%% (limit ±5%%)" % [
			actual_wr, baseline_wr, wr_diff])

	# --- Rule 2: per-reaction fire_count/run within 0.3–3.0 ---
	var actual_rxn:   float = _mean_reactions(actual_rows)
	var baseline_rxn: float = _mean_reactions(baseline_rows)

	if actual_rxn == 0.0 and baseline_rxn == 0.0:
		# Both have no reactions — skip with warning
		print("sim_diff.gd: WARNING — reaction counts are 0 in both actual and baseline; " +
			  "skipping reaction band check (ISSUE-021 will wire reaction_fire_log)")
	else:
		# Check that actual reactions/run is within [0.3, 3.0]
		if actual_rxn < 0.3 or actual_rxn > 3.0:
			breaches.append("REACTION_BAND_BREACH: actual_mean=%.3f (must be 0.3–3.0)" % actual_rxn)

	# --- Report ---
	var exit_code: int = 0
	if breaches.is_empty():
		print("sim_diff.gd: PASS — all checks within tolerance")
		print("  win_rate actual=%.2f%% baseline=%.2f%%" % [actual_wr, baseline_wr])
	else:
		exit_code = 2
		print("sim_diff.gd: FAIL — %d breach(es) found" % breaches.size())
		var diff_lines: PackedStringArray = PackedStringArray()
		diff_lines.append("=== sim_diff report ===")
		diff_lines.append("actual:   " + actual_path)
		diff_lines.append("baseline: " + baseline_path)
		diff_lines.append("")
		for b in breaches:
			diff_lines.append("BREACH: " + b)
			print("  " + b)
		var diff_file := FileAccess.open(out_path, FileAccess.WRITE)
		if diff_file != null:
			diff_file.store_string("\n".join(diff_lines) + "\n")
			diff_file.close()
			print("sim_diff.gd: diff report written to " + out_path)

	quit(exit_code)
