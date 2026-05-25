## Smoke + acceptance tests for ISSUE-010b: enemy_ui scene tree.
## Covers PRD §3 US-02 "看意图" gates: intent number changes when state changes,
## carried_traits row reflects enemy data, multiple enemies render side by side.
extends GdUnitTestSuite

const EnemyScript := preload("res://data/enemy.gd")
const TraitScript := preload("res://data/trait.gd")

const EnemyUIScene    := preload("res://ui/enemy_ui.tscn")
const IntentWidgetScene := preload("res://ui/intent_widget.tscn")


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_trait(id: String, school: int) -> Resource:
	var t: Resource = TraitScript.new()
	t.id = id
	t.axis_school = school
	t.flavor = "Test trait %s" % id
	return t


func _make_enemy(intent: String, carried: Array) -> Resource:
	var e: Resource = EnemyScript.new()
	e.id = "skeleton_grunt"
	e.intent = intent
	e.carried_traits = carried
	e.drop_count = 1
	return e


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_enemy_ui_instantiates() -> void:
	var ui: Control = auto_free(EnemyUIScene.instantiate())
	add_child(ui)
	var enemy: Resource = _make_enemy("Attack", [])
	ui.bind(enemy, 30, 30, 8, "zh_CN")
	assert_object(ui).is_not_null()


func test_intent_number_updates_when_state_changes() -> void:
	# US-02 gate: changing intent value rerenders the badge.
	var ui: Control = auto_free(EnemyUIScene.instantiate())
	add_child(ui)
	var enemy: Resource = _make_enemy("Attack", [])

	ui.bind(enemy, 30, 30, 8, "zh_CN")
	var iw: Control = ui.get_node("IntentSlot").get_child(0)
	var label_a: Label = iw.get_node("Label")
	assert_str(label_a.text).is_equal("8")

	# Re-bind with a higher value (simulating a buffed-attack intent for next turn)
	ui.bind(enemy, 30, 30, 14, "zh_CN")
	assert_str(label_a.text).is_equal("14")


func test_intent_locale_switch() -> void:
	var ui: Control = auto_free(EnemyUIScene.instantiate())
	add_child(ui)
	var enemy: Resource = _make_enemy("Block", [])

	ui.bind(enemy, 20, 20, 5, "en")
	var iw: Control = ui.get_node("IntentSlot").get_child(0)
	assert_str(iw.get_tooltip_string()).contains("block")

	ui.bind(enemy, 20, 20, 5, "zh_CN")
	assert_str(iw.get_tooltip_string()).contains("格挡")


func test_carried_traits_row_reflects_enemy_data() -> void:
	# US-02 gate: carried_traits row shows exactly one icon per non-null trait.
	var ui: Control = auto_free(EnemyUIScene.instantiate())
	add_child(ui)
	var t1: Resource = _make_trait("flame_brand", 0)
	var t2: Resource = _make_trait("oil_slick", 1)
	var enemy: Resource = _make_enemy("Attack", [t1, t2])
	ui.bind(enemy, 18, 25, 6, "zh_CN")

	var row: HBoxContainer = ui.get_node("TraitRow")
	assert_int(row.get_child_count()).is_equal(2)


func test_carried_traits_row_handles_string_ids() -> void:
	# Some data fixtures keep carried_traits as id strings — must not crash.
	var ui: Control = auto_free(EnemyUIScene.instantiate())
	add_child(ui)
	var enemy: Resource = _make_enemy("Buff", ["bone_armor", "void_pact", "iron_grip"])
	ui.bind(enemy, 40, 40, 3, "zh_CN")

	var row: HBoxContainer = ui.get_node("TraitRow")
	assert_int(row.get_child_count()).is_equal(3)


func test_hp_label_and_bar() -> void:
	var ui: Control = auto_free(EnemyUIScene.instantiate())
	add_child(ui)
	var enemy: Resource = _make_enemy("Attack", [])
	ui.bind(enemy, 12, 30, 4, "zh_CN")

	var hp_label: Label = ui.get_node("HpLabel")
	var hp_bar: ProgressBar = ui.get_node("HpBar")
	assert_str(hp_label.text).is_equal("12 / 30")
	assert_int(int(hp_bar.value)).is_equal(12)
	assert_int(int(hp_bar.max_value)).is_equal(30)


func test_update_hp_partial_refresh() -> void:
	# update_hp() should not rebuild the trait row, just refresh HP.
	var ui: Control = auto_free(EnemyUIScene.instantiate())
	add_child(ui)
	var t1: Resource = _make_trait("flame_brand", 0)
	var enemy: Resource = _make_enemy("Attack", [t1])
	ui.bind(enemy, 30, 30, 5, "zh_CN")

	var row: HBoxContainer = ui.get_node("TraitRow")
	var initial_icon: Node = row.get_child(0)

	ui.update_hp(11)
	var hp_label: Label = ui.get_node("HpLabel")
	assert_str(hp_label.text).is_equal("11 / 30")
	# Same icon node — trait row was not rebuilt
	assert_object(row.get_child(0)).is_same(initial_icon)


func test_multi_enemy_layout_side_by_side() -> void:
	# US-02 gate: encounter w/ multiple enemies — each gets its own widget.
	var holder: HBoxContainer = auto_free(HBoxContainer.new())
	holder.add_theme_constant_override("separation", 12)
	add_child(holder)

	var e1: Resource = _make_enemy("Attack", [_make_trait("flame_brand", 0)])
	var e2: Resource = _make_enemy("Block",  [_make_trait("oil_slick", 1)])
	var e3: Resource = _make_enemy("Buff",   [])

	for data in [{"e": e1, "v": 8}, {"e": e2, "v": 5}, {"e": e3, "v": 2}]:
		var ui: Control = EnemyUIScene.instantiate()
		holder.add_child(ui)
		ui.bind(data["e"], 20, 20, data["v"], "zh_CN")

	assert_int(holder.get_child_count()).is_equal(3)
	# Each child is an EnemyUI Control with its own intent widget
	for ui_node in holder.get_children():
		var iw: Control = ui_node.get_node("IntentSlot").get_child(0)
		assert_object(iw).is_not_null()
