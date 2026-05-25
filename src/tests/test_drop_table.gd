## GdUnit4 test suite for ISSUE-008: drop_table.gd
extends GdUnitTestSuite

const DropTableScript := preload("res://core/drop_table.gd")
const InventoryManagerScript := preload("res://core/inventory_manager.gd")

# Rarity map matching traits.json
const TRAIT_RARITY_MAP := {
	"flame_brand":  "Common",
	"oil_slick":    "Common",
	"bone_harvest": "Uncommon",
	"lunar_echo":   "Uncommon",
	"void_consume": "Rare"
}

# ---------------------------------------------------------------------------
# drop_count distribution — normal: 10/60/30
# ---------------------------------------------------------------------------

func test_drop_count_distribution_normal_within_3pct() -> void:
	var dt: Object = DropTableScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts: Array = [0, 0, 0]
	var n: int = 1000
	for _i in range(n):
		var c: int = dt.roll_drop_count("normal", rng)
		counts[c] += 1
	# targets: 0→10%, 1→60%, 2→30%
	assert_float(float(counts[0]) / n * 100.0).is_between(7.0, 13.0)
	assert_float(float(counts[1]) / n * 100.0).is_between(57.0, 63.0)
	assert_float(float(counts[2]) / n * 100.0).is_between(27.0, 33.0)


func test_drop_count_distribution_elite_always_2() -> void:
	var dt: Object = DropTableScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i in range(1000):
		assert_int(dt.roll_drop_count("elite", rng)).is_equal(2)


func test_drop_count_distribution_boss_always_3() -> void:
	var dt: Object = DropTableScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for _i in range(1000):
		assert_int(dt.roll_drop_count("boss", rng)).is_equal(3)


# ---------------------------------------------------------------------------
# rarity distribution
# ---------------------------------------------------------------------------

func test_rarity_distribution_normal_within_3pct() -> void:
	var dt: Object = DropTableScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var common_count: int = 0
	var uncommon_count: int = 0
	var rare_count: int = 0
	var n: int = 1000
	for _i in range(n):
		var r: String = dt.roll_rarity("normal", rng)
		if r == "Common":
			common_count += 1
		elif r == "Uncommon":
			uncommon_count += 1
		else:
			rare_count += 1
	assert_float(float(common_count) / n * 100.0).is_between(72.0, 78.0)
	assert_float(float(uncommon_count) / n * 100.0).is_between(19.0, 25.0)
	assert_float(float(rare_count) / n * 100.0).is_between(0.0, 6.0)


func test_rarity_distribution_boss_no_common() -> void:
	var dt: Object = DropTableScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var common_count: int = 0
	for _i in range(1000):
		var r: String = dt.roll_rarity("boss", rng)
		if r == "Common":
			common_count += 1
	assert_int(common_count).is_equal(0)


# ---------------------------------------------------------------------------
# roll_drops pool constraint
# ---------------------------------------------------------------------------

func test_roll_drops_respects_carried_pool() -> void:
	var dt: Object = DropTableScript.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	# Only flame_brand in pool — every drop must be flame_brand
	for _i in range(20):
		var drops: Array = dt.roll_drops(["flame_brand"], "normal", rng, TRAIT_RARITY_MAP)
		for tid in drops:
			assert_str(tid).is_equal("flame_brand")


# ---------------------------------------------------------------------------
# inventory capacity overflow
# ---------------------------------------------------------------------------

func test_inventory_capacity_overflow() -> void:
	var inv_mgr: Object = InventoryManagerScript.new()
	var inventory: Array = []
	var warnings: Array = []
	# Use 7 unique IDs so FIFO eviction is observable.
	var traits: Array = ["t0", "t1", "t2", "t3", "t4", "t5", "t6"]
	for tid in traits:
		inv_mgr.add(inventory, warnings, tid)
	assert_int(inventory.size()).is_equal(5)
	assert_int(warnings.size()).is_equal(2)
	# oldest 2 (t0, t1) were dropped; remaining inventory is FIFO tail
	assert_bool(inventory.has("t0")).is_false()
	assert_bool(inventory.has("t1")).is_false()
	assert_array(inventory).contains(["t2", "t3", "t4", "t5", "t6"])
