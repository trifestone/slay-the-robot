## Smoke test — verifies ISSUE-009b scenes parse and instantiate without errors.
extends GdUnitTestSuite

const TraitScript := preload("res://data/trait.gd")
const SlotScript  := preload("res://data/slot.gd")
const CardScript  := preload("res://data/card.gd")
const BattleStateScript := preload("res://core/battle_state.gd")

const TraitIconScene := preload("res://ui/trait_icon.tscn")
const CardUIScene    := preload("res://ui/card_ui.tscn")
const HandUIScene    := preload("res://ui/hand_ui.tscn")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_trait(id: String, school: int) -> Resource:
	var t: Resource = TraitScript.new()
	t.id = id
	t.trigger = 0
	t.effect_type = "Damage"
	t.effect_value = 4
	t.axis_school = school
	t.axis_timing = 0
	t.axis_scope = 0
	t.rarity = 0
	t.cooldown_per_turn = -1
	return t


func _make_card(id_prefix: String) -> Resource:
	var c: Resource = CardScript.new()
	var slots: Array = []
	for i in range(3):
		var s: Resource = SlotScript.new()
		s.index = i
		s.trait_ref = _make_trait("%s_%d" % [id_prefix, i], i % 6)
		s.post_load()
		slots.append(s)
	c.slots = slots
	return c


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_trait_icon_instantiates() -> void:
	var icon: Control = auto_free(TraitIconScene.instantiate())
	add_child(icon)
	var t: Resource = _make_trait("flame_brand", 0)
	icon.bind(t, true)  # locked
	assert_object(icon).is_not_null()


func test_card_ui_renders_three_slots() -> void:
	var card: Resource = _make_card("c1")
	var ui: Control = auto_free(CardUIScene.instantiate())
	add_child(ui)
	ui.bind(card, 1, "zh_CN")
	# IconRow should have 3 children after bind
	var row: HBoxContainer = ui.get_node("IconRow")
	assert_int(row.get_child_count()).is_equal(3)


func test_hand_ui_renders_five_cards() -> void:
	var state: RefCounted = BattleStateScript.new()
	state.hand = []
	for i in range(5):
		state.hand.append(_make_card("h%d" % i))
	var hand: Control = auto_free(HandUIScene.instantiate())
	add_child(hand)
	hand.bind(state, "zh_CN")
	var row: Control = hand.get_node("Row")
	# Each CardUI is one child of Row
	assert_int(row.get_child_count()).is_equal(5)
	# Each CardUI's IconRow should have exactly 3 trait icons
	for card_ui in row.get_children():
		var icon_row: HBoxContainer = card_ui.get_node("IconRow")
		assert_int(icon_row.get_child_count()).is_equal(3)


func test_card_ui_locale_switch() -> void:
	var card: Resource = _make_card("loc")
	var ui: Control = auto_free(CardUIScene.instantiate())
	add_child(ui)
	ui.bind(card, 1, "en")
	var label: Label = ui.get_node("Effect")
	assert_str(label.text).contains("Deal")
	ui.bind(card, 1, "zh_CN")
	assert_str(label.text).contains("造成")
