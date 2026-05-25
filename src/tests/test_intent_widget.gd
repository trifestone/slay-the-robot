## GdUnit4 test suite for ISSUE-010a: intent_widget.gd resolver.
extends GdUnitTestSuite

const IntentScript := preload("res://ui/intent_widget.gd")
const TraitScript  := preload("res://data/trait.gd")


func test_attack_intent_zh() -> void:
	var w: Object = IntentScript.new()
	var r: Dictionary = w.resolve("Attack", 12, "zh_CN")
	assert_str(r["icon_code"]).is_equal("ATK")
	assert_str(r["label"]).is_equal("12")
	assert_str(r["tooltip"]).is_equal("下回合攻击造成 12 点伤害")
	assert_str(r["intent"]).is_equal("Attack")


func test_attack_intent_en() -> void:
	var w: Object = IntentScript.new()
	var r: Dictionary = w.resolve("Attack", 7, "en")
	assert_str(r["tooltip"]).is_equal("Will attack for 7 damage next turn")


func test_block_intent() -> void:
	var w: Object = IntentScript.new()
	var r: Dictionary = w.resolve("Block", 5, "zh_CN")
	assert_str(r["icon_code"]).is_equal("BLK")
	assert_str(r["label"]).is_equal("5")


func test_buff_intent_shows_plus() -> void:
	var w: Object = IntentScript.new()
	var r: Dictionary = w.resolve("Buff", 2, "zh_CN")
	assert_str(r["label"]).is_equal("+2")
	assert_str(r["icon_code"]).is_equal("BUF")


func test_debuff_intent_shows_minus() -> void:
	var w: Object = IntentScript.new()
	var r: Dictionary = w.resolve("Debuff", 3, "zh_CN")
	assert_str(r["label"]).is_equal("-3")
	assert_str(r["icon_code"]).is_equal("DBF")


func test_multi_intent() -> void:
	var w: Object = IntentScript.new()
	var r: Dictionary = w.resolve("Multi", 4, "en")
	assert_str(r["icon_code"]).is_equal("MUL")
	assert_str(r["tooltip"]).contains("multiple actions")


func test_unknown_intent_falls_back_to_attack() -> void:
	var w: Object = IntentScript.new()
	var r: Dictionary = w.resolve("Mystery", 9, "zh_CN")
	# Falls back to Attack — never crashes
	assert_str(r["intent"]).is_equal("Attack")
	assert_str(r["label"]).is_equal("9")


func test_describe_carried_traits() -> void:
	var w: Object = IntentScript.new()
	var t1: Resource = TraitScript.new()
	t1.id = "flame_brand"
	t1.flavor = "Fire trait"
	var t2: Resource = TraitScript.new()
	t2.id = "oil_slick"
	t2.flavor = "Oily trait"
	var out: Array = w.describe_carried([t1, t2, null])
	# nulls are skipped
	assert_int(out.size()).is_equal(2)
	assert_str(out[0]["id"]).is_equal("flame_brand")
	assert_str(out[1]["flavor"]).is_equal("Oily trait")


func test_color_lookup() -> void:
	var w: Object = IntentScript.new()
	var atk: Dictionary = w.resolve("Attack", 1, "zh_CN")
	var blk: Dictionary = w.resolve("Block", 1, "zh_CN")
	# Colors must differ across intent types so the icon swap is visible.
	assert_bool(atk["color"] != blk["color"]).is_true()
