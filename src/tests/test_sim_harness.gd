## GdUnit4 test suite for ISSUE-019: headless simulation harness.
##
## Fixtures:
##   test_sim_csv_written      — 10-run smoke: CSV file has header + 10 data rows.
##   test_sim_determinism      — same seed_base produces byte-identical CSV on two runs.
extends GdUnitTestSuite

const SimRunnerScript := preload("res://tools/sim_runner.gd")

# Output path in user:// so it is gitignored.
const SMOKE_CSV := "user://sim_smoke.csv"

# ---------------------------------------------------------------------------
# Helper: count non-empty, non-comment lines in a text file
# ---------------------------------------------------------------------------

func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var txt: String = f.get_as_text()
	f.close()
	return txt


func _data_rows(csv_text: String) -> int:
	## Return number of data rows (non-empty, non-comment lines after the header).
	var lines: PackedStringArray = csv_text.split("\n")
	var count: int = 0
	var header_seen: bool = false
	for line in lines:
		var l: String = line.strip_edges()
		if l.is_empty() or l.begins_with("#"):
			continue
		if not header_seen:
			header_seen = true   # first non-blank non-comment line is the header
			continue
		count += 1
	return count


func _has_header(csv_text: String) -> bool:
	## Check that the first non-blank non-comment line is the expected header.
	var lines: PackedStringArray = csv_text.split("\n")
	for line in lines:
		var l: String = line.strip_edges()
		if l.is_empty() or l.begins_with("#"):
			continue
		return l == "run_id,seed,outcome,battles_won,hp_left,gold,traits_collected,reactions_triggered,total_turns"
	return false


# ---------------------------------------------------------------------------
# Fixture 1: CSV file written with header + 10 data rows
# ---------------------------------------------------------------------------

func test_sim_csv_written() -> void:
	var runner: Object = SimRunnerScript.new()
	var result: Dictionary = runner.run_simulation(10, 1, SMOKE_CSV)

	# CSV file must exist and be non-empty
	var csv_text: String = _read_text(SMOKE_CSV)
	assert_bool(csv_text.length() > 0).is_true()

	# First content line must be the canonical header
	assert_bool(_has_header(csv_text)).is_true()

	# Must have exactly 10 data rows
	assert_int(_data_rows(csv_text)).is_equal(10)

	# result dict sanity checks
	assert_int(result["total_runs"]).is_equal(10)
	assert_int(result["rows"].size()).is_equal(10)

	# Each row must have all required keys with valid values
	for row in result["rows"]:
		assert_bool(row.has("run_id")).is_true()
		assert_bool(row.has("seed")).is_true()
		assert_bool(row.has("outcome")).is_true()
		assert_bool(row.has("battles_won")).is_true()
		assert_bool(row.has("hp_left")).is_true()
		assert_bool(row.has("gold")).is_true()
		assert_bool(row.has("traits_collected")).is_true()
		assert_bool(row.has("reactions_triggered")).is_true()
		assert_bool(row.has("total_turns")).is_true()
		var outcome: String = row["outcome"]
		assert_bool(outcome == "won" or outcome == "lost").is_true()


# ---------------------------------------------------------------------------
# Fixture 2: determinism — two runs with same seed_base produce identical CSV
# ---------------------------------------------------------------------------

func test_sim_determinism() -> void:
	const PATH_A := "user://sim_smoke_a.csv"
	const PATH_B := "user://sim_smoke_b.csv"

	var runner_a: Object = SimRunnerScript.new()
	runner_a.run_simulation(10, 1, PATH_A)

	var runner_b: Object = SimRunnerScript.new()
	runner_b.run_simulation(10, 1, PATH_B)

	var text_a: String = _read_text(PATH_A)
	var text_b: String = _read_text(PATH_B)

	assert_bool(text_a.length() > 0).is_true()
	assert_str(text_a).is_equal(text_b)
