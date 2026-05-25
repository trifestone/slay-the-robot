## GdUnit4 test suite for ISSUE-009a: card_ui_resolver.gd
extends GdUnitTestSuite

const ResolverScript := preload("res://ui/card_ui_resolver.gd")
const TraitScript    := preload("res://data/trait.gd")
const SlotScript     := preload("res://data/slot.gd")
const CardScript     := preload("res://data/card.gd")
const EnumsScript    := preload("res://core/enums.gd")

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_trait(effect_type: String, value: int, school: int, trigger: int = 0) -> Resource:
	var t: Resource = TraitScript.new()
	t.id = "test_%s_%d" % [effect_type.to_lower(), value]
	t.trigger = trigger
	t.effect_type = effect_type
	t.effect_value = value
	t.axis_timing = trigger
	t.axis_scope = 0
	t.axis_school = school
	t.rarity = 0
	t.cooldown_per_turn = -1
	return t


func _make_slot(idx: int, t: Resource) -> Resource:
	var s: Resource = SlotScript.new()
	s.index = idx
	s.trait_ref = t
	s.post_load()
	return s


func _make_card_with_traits(traits: Array) -> Resource:
	var c: Resource = CardScript.new()
	var slots: Array = []
	for i in range(3):
		slots.append(_make_slot(i, traits[i] if i < traits.size() else null))
	c.slots = slots
	return c


# ---------------------------------------------------------------------------
# Case 1 — Attack with 3 traits, zh-CN
# ---------------------------------------------------------------------------

func test_compose_attack_three_traits_zh() -> void:
	var resolver: Object = ResolverScript.new()
	# slot0: 4 Fire damage, slot1: 2 Bone damage, slot2: draw 1
	var t0: Resource = _make_trait("Damage", 4, Enums.School.Fire)
	var t1: Resource = _make_trait("Damage", 2, Enums.School.Bone)
	var t2: Resource = _make_trait("Draw", 1, Enums.School.Moon)
	var card: Resource = _make_card_with_traits([t0, t1, t2])
	var s: String = resolver.compose(card, "zh_CN")
	assert_str(s).contains("造成 4 点 火焰伤害")
	assert_str(s).contains("造成 2 点 尸骨伤害")
	assert_str(s).contains("抽 1 张牌")
	# joiner present twice
	assert_int(s.count(" + ")).is_equal(2)


# ---------------------------------------------------------------------------
# Case 2 — Reaction-pair card (flame_brand + oil_slick), en
# ---------------------------------------------------------------------------

func test_compose_reaction_pair_en() -> void:
	var resolver: Object = ResolverScript.new()
	var flame: Resource = _make_trait("Damage", 4, Enums.School.Fire)
	var oil: Resource   = _make_trait("Apply", 1, Enums.School.Fire)
	var empty_filler: Resource = _make_trait("Damage", 1, Enums.School.Iron)
	var card: Resource = _make_card_with_traits([flame, oil, empty_filler])
	var s: String = resolver.compose(card, "en")
	assert_str(s).contains("Deal 4 Fire damage")
	assert_str(s).contains("apply 1 Oil")
	assert_str(s).contains("Deal 1 Iron damage")


# ---------------------------------------------------------------------------
# Case 3 — Card with empty slot[2], zh-CN
# ---------------------------------------------------------------------------

func test_compose_empty_slot_omitted_zh() -> void:
	var resolver: Object = ResolverScript.new()
	var t0: Resource = _make_trait("Damage", 5, Enums.School.Fire)
	var t1: Resource = _make_trait("Apply", 2, Enums.School.Decay)
	# slot 2 left null
	var card: Resource = _make_card_with_traits([t0, t1, null])
	var s: String = resolver.compose(card, "zh_CN")
	assert_str(s).contains("造成 5 点 火焰伤害")
	assert_str(s).contains("给目标 2 层 腐蚀")
	# Only one joiner because slot 2 is empty
	assert_int(s.count(" + ")).is_equal(1)


# ---------------------------------------------------------------------------
# Case 4 — Locked slot[0] still renders (lock is a UI concern, not text)
# ---------------------------------------------------------------------------

func test_locked_slot_still_renders() -> void:
	var resolver: Object = ResolverScript.new()
	var locked_trait: Resource = _make_trait("Damage", 6, Enums.School.Iron)
	var card: Resource = _make_card_with_traits([locked_trait, null, null])
	# slot 0 must be locked per Card invariant
	assert_bool(card.slots[0].locked).is_true()
	var s_zh: String = resolver.compose(card, "zh_CN")
	var s_en: String = resolver.compose(card, "en")
	assert_str(s_zh).is_equal("造成 6 点 钢铁伤害")
	assert_str(s_en).is_equal("Deal 6 Iron damage")


# ---------------------------------------------------------------------------
# Case 5 — English plural correctness for Draw
# ---------------------------------------------------------------------------

func test_english_draw_pluralization() -> void:
	var resolver: Object = ResolverScript.new()
	var draw1: Resource = _make_trait("Draw", 1, Enums.School.Moon)
	var draw2: Resource = _make_trait("Draw", 2, Enums.School.Moon)
	var c1: Resource = _make_card_with_traits([draw1, null, null])
	var c2: Resource = _make_card_with_traits([draw2, null, null])
	assert_str(resolver.compose(c1, "en")).is_equal("draw 1 card")
	assert_str(resolver.compose(c2, "en")).is_equal("draw 2 cards")


# ---------------------------------------------------------------------------
# Case 6 — Null card returns empty string (defensive)
# ---------------------------------------------------------------------------

func test_null_card_returns_empty() -> void:
	var resolver: Object = ResolverScript.new()
	assert_str(resolver.compose(null, "zh_CN")).is_equal("")
	assert_str(resolver.compose(null, "en")).is_equal("")
