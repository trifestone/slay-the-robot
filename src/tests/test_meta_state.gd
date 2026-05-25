## ISSUE-018a — Tests for meta-progression state machine + unlock table + lore store.
## Verifies threshold-driven unlocks, save/load round-trip, in-run reset
## correctness (well, no in-run state lives here — meta is cross-run only),
## min-reward path on first-battle death (US-15), and themed-build lore (US-14).
extends GdUnitTestSuite

const Meta        := preload("res://meta/meta_state.gd")
const UnlockTable := preload("res://meta/unlock_table.gd")
const LoreStore   := preload("res://meta/lore_store.gd")


func _won_summary(traits: Array = [], element_map: Dictionary = {}) -> Dictionary:
	return {
		"won":                  true,
		"first_battle_death":   false,
		"traits_collected":     traits,
		"trait_element_map":    element_map,
	}


func _lost_summary(first_battle: bool = false) -> Dictionary:
	return {
		"won":                  false,
		"first_battle_death":   first_battle,
		"traits_collected":     [],
		"trait_element_map":    {},
	}


# ---------------------------------------------------------------------------
# Default state
# ---------------------------------------------------------------------------

func test_default_meta_starts_with_witch_1_and_zero_progress() -> void:
	var m: Object = Meta.new()
	var meta: Dictionary = m.make_default()
	assert_int(meta["runs_total"]).is_equal(0)
	assert_int(meta["wins_total"]).is_equal(0)
	assert_int(meta["xp"]).is_equal(0)
	assert_array(meta["unlocked_witches"]).contains_exactly(["witch_1"])
	assert_int(meta["unlocked_traits"].size()).is_equal(0)


# ---------------------------------------------------------------------------
# Threshold unlocks
# ---------------------------------------------------------------------------

func test_first_win_grants_lore_and_starter_trait() -> void:
	var m: Object = Meta.new()
	var meta: Dictionary = m.make_default()
	var delta: Dictionary = m.apply_run_result(meta, _won_summary())

	assert_int(meta["wins_total"]).is_equal(1)
	assert_array(meta["unlocked_lore"]).contains(["lore_first_win"])
	assert_array(meta["unlocked_traits"]).contains(["trait_unlock_run1"])
	assert_int(int(delta["xp_gained"])).is_equal(10)
	assert_int(delta["new_unlocks"].size()).is_greater_equal(2)


func test_fifth_win_unlocks_witch_and_base() -> void:
	var m: Object = Meta.new()
	var meta: Dictionary = m.make_default()
	for i in range(5):
		m.apply_run_result(meta, _won_summary())
	assert_int(meta["wins_total"]).is_equal(5)
	assert_array(meta["unlocked_witches"]).contains(["witch_2"])
	assert_array(meta["unlocked_bases"]).contains(["base_unlock_run5"])


func test_intermediate_wins_grant_no_unlock_at_run_2() -> void:
	var m: Object = Meta.new()
	var meta: Dictionary = m.make_default()
	# Win 1 fires thresholds, win 2 should fire nothing.
	m.apply_run_result(meta, _won_summary())
	var delta: Dictionary = m.apply_run_result(meta, _won_summary())
	assert_int(delta["new_unlocks"].size()).is_equal(0)


func test_unlock_is_idempotent_when_replayed() -> void:
	# Defensive: if save data ever advances win_count and re-applies, the
	# same trait id should not duplicate in unlocked_traits.
	var m: Object = Meta.new()
	var meta: Dictionary = m.make_default()
	# Manually pre-grant.
	meta["unlocked_traits"].append("trait_unlock_run1")
	var delta: Dictionary = m.apply_run_result(meta, _won_summary())

	# trait_unlock_run1 was already there, so it shouldn't be in delta.new_unlocks.
	var has_dup: bool = false
	for u in delta["new_unlocks"]:
		if u["kind"] == "trait" and u["id"] == "trait_unlock_run1":
			has_dup = true
	assert_bool(has_dup).is_false()
	# And only one copy in the list.
	var count: int = 0
	for tid in meta["unlocked_traits"]:
		if tid == "trait_unlock_run1":
			count += 1
	assert_int(count).is_equal(1)


# ---------------------------------------------------------------------------
# US-15 min-reward
# ---------------------------------------------------------------------------

func test_first_battle_death_grants_min_reward() -> void:
	var m: Object = Meta.new()
	var meta: Dictionary = m.make_default()
	var delta: Dictionary = m.apply_run_result(meta, _lost_summary(true))

	assert_array(meta["unlocked_traits"]).contains(["trait_min_reward"])
	assert_array(meta["unlocked_lore"]).contains(["lore_min_reward"])
	assert_int(meta["wins_total"]).is_equal(0)
	# At least 1 trait + 1 lore in delta
	assert_int(delta["new_unlocks"].size()).is_greater_equal(2)


func test_normal_loss_grants_only_xp() -> void:
	var m: Object = Meta.new()
	var meta: Dictionary = m.make_default()
	var delta: Dictionary = m.apply_run_result(meta, _lost_summary(false))
	assert_int(meta["wins_total"]).is_equal(0)
	assert_int(meta["xp"]).is_equal(1)
	assert_int(delta["new_unlocks"].size()).is_equal(0)


# ---------------------------------------------------------------------------
# Themed-build lore (US-14)
# ---------------------------------------------------------------------------

func test_themed_fire_win_unlocks_themed_lore() -> void:
	var m: Object = Meta.new()
	var meta: Dictionary = m.make_default()
	# 5 fire traits / 5 total = 100% themed.
	var traits := ["fb1", "fb2", "fb3", "fb4", "fb5"]
	var em: Dictionary = {
		"fb1": "Fire", "fb2": "Fire", "fb3": "Fire", "fb4": "Fire", "fb5": "Fire",
	}
	m.apply_run_result(meta, _won_summary(traits, em))
	assert_array(meta["unlocked_lore"]).contains(["lore_themed_fire"])


func test_mixed_build_does_not_unlock_themed_lore() -> void:
	var m: Object = Meta.new()
	var meta: Dictionary = m.make_default()
	# 50/50 split is below 80% threshold.
	var traits := ["a", "b", "c", "d"]
	var em: Dictionary = {"a": "Fire", "b": "Fire", "c": "Void", "d": "Void"}
	m.apply_run_result(meta, _won_summary(traits, em))
	var has: bool = meta["unlocked_lore"].has("lore_themed_fire") or meta["unlocked_lore"].has("lore_themed_void")
	assert_bool(has).is_false()


# ---------------------------------------------------------------------------
# Save / load round-trip
# ---------------------------------------------------------------------------

func test_save_load_roundtrip_preserves_state() -> void:
	var m: Object = Meta.new()
	var meta: Dictionary = m.make_default()
	m.apply_run_result(meta, _won_summary())  # win 1
	m.apply_run_result(meta, _lost_summary())

	var json: String = m.to_json(meta)
	var loaded: Dictionary = m.from_json(json)

	assert_int(int(loaded["wins_total"])).is_equal(int(meta["wins_total"]))
	assert_int(int(loaded["runs_total"])).is_equal(int(meta["runs_total"]))
	assert_int(int(loaded["xp"])).is_equal(int(meta["xp"]))
	assert_array(loaded["unlocked_traits"]).contains_exactly(meta["unlocked_traits"])
	assert_array(loaded["unlocked_lore"]).contains_exactly(meta["unlocked_lore"])


func test_from_json_returns_default_on_garbage() -> void:
	var m: Object = Meta.new()
	var loaded: Dictionary = m.from_json("not json {{{")
	assert_int(int(loaded["wins_total"])).is_equal(0)


func test_from_json_backfills_missing_keys() -> void:
	# Older save with only a subset of keys should not crash.
	var m: Object = Meta.new()
	var partial: String = '{"version":1,"wins_total":3}'
	var loaded: Dictionary = m.from_json(partial)
	assert_int(int(loaded["wins_total"])).is_equal(3)
	assert_array(loaded["unlocked_witches"]).contains(["witch_1"])  # default


# ---------------------------------------------------------------------------
# UnlockTable structural pin
# ---------------------------------------------------------------------------

func test_unlock_table_thresholds_match_prd() -> void:
	var ut: Object = UnlockTable.new()
	assert_array(ut.thresholds()).contains_exactly([1, 5, 20, 50])


# ---------------------------------------------------------------------------
# LoreStore basics
# ---------------------------------------------------------------------------

func test_lore_store_lookup_by_id() -> void:
	var ls: Object = LoreStore.new()
	var f: Variant = ls.fragment_by_id("lore_first_win")
	assert_str(String(f["title"])).is_equal("Ash on the Hearth")


func test_lore_store_returns_null_for_unknown_id() -> void:
	var ls: Object = LoreStore.new()
	var f: Variant = ls.fragment_by_id("nonexistent")
	assert_object(f).is_null()
