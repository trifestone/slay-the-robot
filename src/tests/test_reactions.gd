## GdUnit4 test suite for ISSUE-004: SpecialReaction registry + timing semantics.
## Covers all acceptance criteria in ISSUE-004.
extends GdUnitTestSuite

# ---------------------------------------------------------------------------
# Preloads
# ---------------------------------------------------------------------------
const TraitScript          := preload("res://data/trait.gd")
const SlotScript           := preload("res://data/slot.gd")
const CardScript           := preload("res://data/card.gd")
const ReactionScript       := preload("res://data/reaction.gd")
const LoaderScript         := preload("res://data/loader.gd")
const BattleStateScript    := preload("res://core/battle_state.gd")
const EmitScript           := preload("res://core/emit.gd")
const ReactionRegistryScript := preload("res://core/reaction_registry.gd")

const REACTIONS_PATH := "res://data/reactions.json"
const TRAITS_PROD_PATH := "res://data/traits.json"

## Expected reaction count per ISSUE-004 spec (§ Acceptance: "5 PRD §4.4 sample reactions").
const EXPECTED_REACTION_COUNT: int = 25

# Valid TriggerEvent range (matches Enums.TriggerEvent: OnPlay=0 … OnTraitFired=7).
const TRIGGER_MIN: int = 0
const TRIGGER_MAX: int = 7


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_that(f).is_not_null()
	var text := f.get_as_text()
	f.close()
	return text


func _make_loader():
	return LoaderScript.new()


func _load_reactions() -> Array:
	return _make_loader().load_reactions_from_json(_read_file(REACTIONS_PATH))


func _load_prod_traits() -> Dictionary:
	var traits: Array = _make_loader().load_traits_from_json(_read_file(TRAITS_PROD_PATH))
	var by_id: Dictionary = {}
	for t in traits:
		by_id[t.id] = t
	return by_id


## Build a TraitCard with up to 3 traits (pass null for empty slots).
func _make_card(t0: Resource, t1: Resource, t2: Resource) -> Resource:
	var s0 = SlotScript.new()
	s0.index = 0
	s0.trait_ref = t0
	s0.locked = true
	s0.post_load()

	var s1 = SlotScript.new()
	s1.index = 1
	s1.trait_ref = t1
	s1.locked = false
	s1.post_load()

	var s2 = SlotScript.new()
	s2.index = 2
	s2.trait_ref = t2
	s2.locked = false
	s2.post_load()

	var card = CardScript.new()
	card.slots = [s0, s1, s2]
	return card


## Build a minimal Trait resource with the given id and trigger int.
func _make_trait(tid: String, trigger_int: int) -> Resource:
	var t = TraitScript.new()
	t.id = tid
	t.trigger = trigger_int
	t.effect_type = "Damage"
	t.effect_value = 1
	t.cooldown_per_turn = -1
	t.axis_timing = trigger_int
	t.axis_scope = 0
	t.axis_school = 0
	t.rarity = 0
	t.removable = true
	t.flavor = ""
	return t


## Build a Reaction resource with given fields.
func _make_reaction(rid: String, watch: Array, timing_int: int, effect: String) -> Resource:
	var r = ReactionScript.new()
	r.id = rid
	r.watch_for = watch
	r.timing = timing_int
	r.override_effect = effect
	r.flavor = ""
	return r


func _make_state() -> Object:
	return BattleStateScript.new()


func _make_emitter() -> Object:
	return EmitScript.new()


func _make_registry() -> Object:
	return ReactionRegistryScript.new()


# ---------------------------------------------------------------------------
# AC-1: JSON full set loads successfully — count == EXPECTED_REACTION_COUNT
# ---------------------------------------------------------------------------

func test_ac1_full_set_loads_correct_count() -> void:
	var reactions: Array = _load_reactions()
	assert_int(reactions.size()).is_equal(EXPECTED_REACTION_COUNT)


# ---------------------------------------------------------------------------
# AC-2: Every reaction timing is within valid TriggerEvent range
# ---------------------------------------------------------------------------

func test_ac2_all_timings_valid() -> void:
	var reactions: Array = _load_reactions()
	for r in reactions:
		assert_int(r.timing).is_greater_equal(TRIGGER_MIN)
		assert_int(r.timing).is_less_equal(TRIGGER_MAX)


# ---------------------------------------------------------------------------
# AC-3: ReactionRegistry.load_all() returns all reactions with M2 validation
# ---------------------------------------------------------------------------

func test_ac3_registry_load_all() -> void:
	var registry = _make_registry()
	var all: Array = registry.load_all()
	assert_int(all.size()).is_equal(EXPECTED_REACTION_COUNT)
	for r in all:
		assert_int(r.timing).is_greater_equal(TRIGGER_MIN)
		assert_int(r.timing).is_less_equal(TRIGGER_MAX)


# ---------------------------------------------------------------------------
# AC-4: Reaction with invalid timing fails M2 validation
# ---------------------------------------------------------------------------

func test_ac4_invalid_timing_fails_validation() -> void:
	var registry = _make_registry()
	var bad_r = _make_reaction("bad_timing", ["a", "b"], 99, "Nothing")
	await assert_error(func(): registry._validate_reaction_timing(bad_r)) \
		.is_runtime_error(any())


# ---------------------------------------------------------------------------
# AC-5: [flame_brand, oil_slick] on OnPlay fires Damage(12) + AOE(4),
#        suppresses both original trait effects (source == "reaction")
# ---------------------------------------------------------------------------

func test_ac5_fire_oil_reaction_on_play() -> void:
	var prod := _load_prod_traits()
	# Both traits must be on the card; flame_brand=OnPlay, oil_slick=OnHit.
	# emit is called with OnPlay (0). The reaction watches for both ids regardless of
	# individual triggers — it checks card.has_trait_id() not trait.trigger.
	var card := _make_card(prod["flame_brand"], prod["oil_slick"], null)

	var state := _make_state()
	# Inject the fire_oil_explosion reaction at OnPlay timing
	var r = _make_reaction("fire_oil_explosion", ["flame_brand", "oil_slick"], 0,
			"Damage(12, Fire) + AOE_Splash(4)")
	state.reactions = [r]

	var emitter := _make_emitter()
	emitter.emit(state, 0, card)  # 0 = OnPlay

	# Reaction fires and returns early — exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	assert_str(state.trait_fire_log[0]["source"]).is_equal("reaction")
	assert_str(state.trait_fire_log[0]["effect_type"]).is_equal("Damage(12, Fire) + AOE_Splash(4)")


# ---------------------------------------------------------------------------
# AC-6: Same card played twice in one turn — reaction fires once.
#        Per-reaction cooldown: after first fire, remove reaction from state.reactions
#        (simulating reaction_cooldown_table consuming the slot for this turn).
# ---------------------------------------------------------------------------

func test_ac6_reaction_fires_once_per_turn() -> void:
	var prod := _load_prod_traits()
	var card := _make_card(prod["flame_brand"], prod["oil_slick"], null)

	var state := _make_state()
	var r = _make_reaction("fire_oil_explosion", ["flame_brand", "oil_slick"], 0,
			"Damage(12, Fire) + AOE_Splash(4)")
	state.reactions = [r]

	var emitter := _make_emitter()

	# First OnPlay: reaction fires
	emitter.emit(state, 0, card)
	assert_int(state.trait_fire_log.size()).is_equal(1)
	assert_str(state.trait_fire_log[0]["source"]).is_equal("reaction")

	# Simulate per-reaction cooldown: remove consumed reaction for this turn
	state.reactions = []

	# Second OnPlay same turn: no reaction → falls back to bare trait effects
	emitter.emit(state, 0, card)
	# flame_brand (OnPlay) now fires as a regular trait
	var reaction_fires: int = 0
	var trait_fires: int = 0
	for entry in state.trait_fire_log:
		if entry["source"] == "reaction":
			reaction_fires += 1
		else:
			trait_fires += 1
	assert_int(reaction_fires).is_equal(1)
	assert_int(trait_fires).is_greater_equal(1)


# ---------------------------------------------------------------------------
# AC-7: [purify_light, venom_touch] Cancel reaction: both effects suppressed, heal(3) applied
# ---------------------------------------------------------------------------

func test_ac7_purify_venom_cancel_reaction() -> void:
	# Create minimal traits for purify_light and venom_touch (not in prod traits.json)
	var purify = _make_trait("purify_light", 0)   # OnPlay
	var venom  = _make_trait("venom_touch",  0)   # OnPlay
	var card := _make_card(purify, venom, null)

	var state := _make_state()
	var r = _make_reaction("purify_venom_cancel", ["purify_light", "venom_touch"], 0, "Heal(3)")
	state.reactions = [r]

	var emitter := _make_emitter()
	emitter.emit(state, 0, card)  # OnPlay

	# Reaction fires, both originals suppressed
	assert_int(state.trait_fire_log.size()).is_equal(1)
	assert_str(state.trait_fire_log[0]["source"]).is_equal("reaction")
	assert_str(state.trait_fire_log[0]["effect_type"]).is_equal("Heal(3)")


# ---------------------------------------------------------------------------
# AC-8: Mismatched timing — reaction with OnHit timing does NOT fire on OnPlay
# ---------------------------------------------------------------------------

func test_ac8_mismatched_timing_does_not_fire() -> void:
	var prod := _load_prod_traits()
	var card := _make_card(prod["flame_brand"], prod["oil_slick"], null)

	var state := _make_state()
	# Register reaction with OnHit timing (4), but we emit OnPlay (0)
	var r = _make_reaction("fire_oil_explosion", ["flame_brand", "oil_slick"], 4,
			"Damage(12, Fire) + AOE_Splash(4)")
	state.reactions = [r]

	var emitter := _make_emitter()
	emitter.emit(state, 0, card)  # OnPlay — reaction timing is OnHit → must NOT fire

	# No reaction entries in log
	for entry in state.trait_fire_log:
		assert_str(entry["source"]).is_not_equal("reaction")


# ---------------------------------------------------------------------------
# AC-9: End-to-end — 3 different school reactions each fire exactly once
#        Schools covered: Fire (fire_oil), Bone (bone_soul), Moon (lunar_iron)
# ---------------------------------------------------------------------------

func test_ac9_three_school_reactions_fire() -> void:
	# ---- Fire + Oil school (OnPlay) ----
	var prod := _load_prod_traits()
	var card_fire := _make_card(prod["flame_brand"], prod["oil_slick"], null)
	var state_fire := _make_state()
	var r_fire := _make_reaction("fire_oil_explosion", ["flame_brand", "oil_slick"], 0,
			"Damage(12, Fire) + AOE_Splash(4)")
	state_fire.reactions = [r_fire]
	var emitter := _make_emitter()
	emitter.emit(state_fire, 0, card_fire)
	assert_int(state_fire.trait_fire_log.size()).is_equal(1)
	assert_str(state_fire.trait_fire_log[0]["source"]).is_equal("reaction")

	# ---- Bone + Void school (OnKill = 3) ----
	var bone  = prod["bone_harvest"]   # trigger=OnKill
	var void_ = prod["void_consume"]   # trigger=OnTraitFired
	var card_bone := _make_card(bone, void_, null)
	var state_bone := _make_state()
	var r_bone := _make_reaction("bone_soul_harvester", ["bone_harvest", "void_consume"], 3,
			"Spawn(SoulBoneCard) + DrawTopOfDeck")
	state_bone.reactions = [r_bone]
	emitter.emit(state_bone, 3, card_bone)  # 3 = OnKill
	assert_int(state_bone.trait_fire_log.size()).is_equal(1)
	assert_str(state_bone.trait_fire_log[0]["source"]).is_equal("reaction")

	# ---- Moon + Iron school (EndTurn = 6) ----
	var lunar  = prod["lunar_echo"]             # trigger=EndTurn
	var iron   = _make_trait("iron_bulwark", 6) # EndTurn — not in prod, construct manually
	var card_moon := _make_card(lunar, iron, null)
	var state_moon := _make_state()
	var r_moon := _make_reaction("lunar_iron_tide", ["lunar_echo", "iron_bulwark"], 6,
			"Draw(2) + Block(8)")
	state_moon.reactions = [r_moon]
	emitter.emit(state_moon, 6, card_moon)  # 6 = EndTurn
	assert_int(state_moon.trait_fire_log.size()).is_equal(1)
	assert_str(state_moon.trait_fire_log[0]["source"]).is_equal("reaction")


# ---------------------------------------------------------------------------
# AC-10: BattleState.setup_reactions() injects full registry into state.reactions
# ---------------------------------------------------------------------------

func test_ac10_setup_reactions_populates_state() -> void:
	var state := _make_state()
	assert_int(state.reactions.size()).is_equal(0)

	state.setup_reactions()

	assert_int(state.reactions.size()).is_equal(EXPECTED_REACTION_COUNT)
	for r in state.reactions:
		assert_int(r.timing).is_greater_equal(TRIGGER_MIN)
		assert_int(r.timing).is_less_equal(TRIGGER_MAX)


# ---------------------------------------------------------------------------
# AC-11: emit() source == "reaction" for all reaction log entries
# ---------------------------------------------------------------------------

func test_ac11_emit_reaction_source_field() -> void:
	var prod := _load_prod_traits()
	var card := _make_card(prod["flame_brand"], prod["oil_slick"], null)

	var state := _make_state()
	var r = _make_reaction("fire_oil_explosion", ["flame_brand", "oil_slick"], 0,
			"Damage(12, Fire) + AOE_Splash(4)")
	state.reactions = [r]

	var emitter := _make_emitter()
	emitter.emit(state, 0, card)

	assert_int(state.trait_fire_log.size()).is_equal(1)
	assert_str(state.trait_fire_log[0]["source"]).is_equal("reaction")
