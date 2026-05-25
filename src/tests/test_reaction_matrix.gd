## GdUnit4 test suite for ISSUE-021: Reaction coverage matrix.
## Parameterized over all 25 reaction ids 鈥?one test function per reaction.
## TODO: Add en locale .po file in a future ticket (zh-CN flavor only for now).
extends GdUnitTestSuite

const TraitScript          := preload("res://data/trait.gd")
const SlotScript           := preload("res://data/slot.gd")
const CardScript           := preload("res://data/card.gd")
const ReactionScript       := preload("res://data/reaction.gd")
const LoaderScript         := preload("res://data/loader.gd")
const BattleStateScript    := preload("res://core/battle_state.gd")
const EmitScript           := preload("res://core/emit.gd")

const TRAITS_PATH    := "res://data/traits.json"
const REACTIONS_PATH := "res://data/reactions.json"


func _read_file(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	assert_that(f).is_not_null()
	var text := f.get_as_text()
	f.close()
	return text


func _load_traits_by_id() -> Dictionary:
	var loader = LoaderScript.new()
	var arr: Array = loader.load_traits_from_json(_read_file(TRAITS_PATH))
	var d: Dictionary = {}
	for t in arr:
		d[t.id] = t
	return d


func _load_reactions_by_id() -> Dictionary:
	var loader = LoaderScript.new()
	var arr: Array = loader.load_reactions_from_json(_read_file(REACTIONS_PATH))
	var d: Dictionary = {}
	for r in arr:
		d[r.id] = r
	return d


## Build a card with two traits, one in slot 0, one in slot 1.
func _make_card2(t0: Resource, t1: Resource) -> Resource:
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
	s2.locked = false
	s2.post_load()
	var card = CardScript.new()
	card.slots = [s0, s1, s2]
	return card


## Build a minimal Trait resource with given id and trigger int.
func _make_trait_stub(tid: String, trigger_int: int, effect_type: String, effect_value: int) -> Resource:
	var t = TraitScript.new()
	t.id = tid
	t.trigger = trigger_int
	t.effect_type = effect_type
	t.effect_value = effect_value
	t.cooldown_per_turn = -1 if trigger_int != 3 and trigger_int != 7 else 1
	t.axis_timing = trigger_int
	t.axis_scope = 0
	t.axis_school = 0
	t.rarity = 0
	t.removable = true
	t.flavor = ""
	return t


func test_reaction_fire_oil_explosion() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["fire_oil_explosion"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("flame_brand"):
		t0_res = by_id["flame_brand"]
	else:
		t0_res = _make_trait_stub("flame_brand", 0, "Damage", 4)
	if by_id.has("oil_slick"):
		t1_res = by_id["oil_slick"]
	else:
		t1_res = _make_trait_stub("oil_slick", 0, "Apply", 1)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Damage(12, Fire) + AOE_Splash(4)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_bone_soul_harvester() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["bone_soul_harvester"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("bone_harvest"):
		t0_res = by_id["bone_harvest"]
	else:
		t0_res = _make_trait_stub("bone_harvest", 3, "Spawn", 1)
	if by_id.has("void_consume"):
		t1_res = by_id["void_consume"]
	else:
		t1_res = _make_trait_stub("void_consume", 3, "HealSelfPercent", 5)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Spawn(SoulBoneCard) + DrawTopOfDeck")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_lunar_iron_tide() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["lunar_iron_tide"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("lunar_echo"):
		t0_res = by_id["lunar_echo"]
	else:
		t0_res = _make_trait_stub("lunar_echo", 6, "Draw", 1)
	if by_id.has("iron_bulwark"):
		t1_res = by_id["iron_bulwark"]
	else:
		t1_res = _make_trait_stub("iron_bulwark", 6, "Block", 5)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 6, card)  # EndTurn
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Draw(2) + Block(8)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_purify_venom_cancel() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["purify_venom_cancel"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("purify_light"):
		t0_res = by_id["purify_light"]
	else:
		t0_res = _make_trait_stub("purify_light", 0, "HealSelfPercent", 6)
	if by_id.has("venom_touch"):
		t1_res = by_id["venom_touch"]
	else:
		t1_res = _make_trait_stub("venom_touch", 0, "Apply", 2)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Heal(3)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_decay_bone_rot() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["decay_bone_rot"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("rot_spore"):
		t0_res = by_id["rot_spore"]
	else:
		t0_res = _make_trait_stub("rot_spore", 4, "Apply", 2)
	if by_id.has("bone_harvest"):
		t1_res = by_id["bone_harvest"]
	else:
		t1_res = _make_trait_stub("bone_harvest", 4, "Spawn", 1)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 4, card)  # OnHit
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Apply(Rot, 2) + WeakenArmor(3)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_blaze_char_inferno() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["blaze_char_inferno"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("blaze_echo"):
		t0_res = by_id["blaze_echo"]
	else:
		t0_res = _make_trait_stub("blaze_echo", 2, "Damage", 3)
	if by_id.has("char_mark"):
		t1_res = by_id["char_mark"]
	else:
		t1_res = _make_trait_stub("char_mark", 2, "Apply", 2)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 2, card)  # OnDiscard
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Damage(10, Fire) + Apply(Burn, 3)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_scorch_chain_nova() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["scorch_chain_nova"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("scorch_pulse"):
		t0_res = by_id["scorch_pulse"]
	else:
		t0_res = _make_trait_stub("scorch_pulse", 3, "Damage", 6)
	if by_id.has("fire_chain"):
		t1_res = by_id["fire_chain"]
	else:
		t1_res = _make_trait_stub("fire_chain", 3, "Damage", 2)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Damage(15, Fire) + AOE_Splash(6)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_decay_mold_plague() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["decay_mold_plague"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("mold_growth"):
		t0_res = by_id["mold_growth"]
	else:
		t0_res = _make_trait_stub("mold_growth", 5, "Apply", 1)
	if by_id.has("necrotic_pulse"):
		t1_res = by_id["necrotic_pulse"]
	else:
		t1_res = _make_trait_stub("necrotic_pulse", 5, "Damage", 2)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Apply(Plague, 4) + Damage(3, Decay)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_entropy_blight_storm() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["entropy_blight_storm"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("entropy_wave"):
		t0_res = by_id["entropy_wave"]
	else:
		t0_res = _make_trait_stub("entropy_wave", 7, "Apply", 2)
	if by_id.has("blight_echo"):
		t1_res = by_id["blight_echo"]
	else:
		t1_res = _make_trait_stub("blight_echo", 7, "Damage", 2)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 7, card)  # OnTraitFired
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Apply(Corrosion, 5) + Damage(4, Decay)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_moon_silver_tide() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["moon_silver_tide"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("lunar_tide"):
		t0_res = by_id["lunar_tide"]
	else:
		t0_res = _make_trait_stub("lunar_tide", 0, "Draw", 1)
	if by_id.has("silver_draw"):
		t1_res = by_id["silver_draw"]
	else:
		t1_res = _make_trait_stub("silver_draw", 0, "Buff", 1)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Draw(3) + HealSelf(8%)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_moon_veil_resonance() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["moon_veil_resonance"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("moon_veil"):
		t0_res = by_id["moon_veil"]
	else:
		t0_res = _make_trait_stub("moon_veil", 5, "Block", 6)
	if by_id.has("crescent_guard"):
		t1_res = by_id["crescent_guard"]
	else:
		t1_res = _make_trait_stub("crescent_guard", 5, "Block", 4)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Block(15) + Buff(MoonShield, 2)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_lunar_echo_surge() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["lunar_echo_surge"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("lunar_echo"):
		t0_res = by_id["lunar_echo"]
	else:
		t0_res = _make_trait_stub("lunar_echo", 6, "Draw", 1)
	if by_id.has("full_moon_surge"):
		t1_res = by_id["full_moon_surge"]
	else:
		t1_res = _make_trait_stub("full_moon_surge", 6, "Buff", 2)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 6, card)  # EndTurn
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Draw(2) + Buff(Moon, 3)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_iron_bastion_wall() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["iron_bastion_wall"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("iron_bulwark"):
		t0_res = by_id["iron_bulwark"]
	else:
		t0_res = _make_trait_stub("iron_bulwark", 6, "Block", 5)
	if by_id.has("bastion"):
		t1_res = by_id["bastion"]
	else:
		t1_res = _make_trait_stub("bastion", 6, "Block", 8)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 6, card)  # EndTurn
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Block(18) + Buff(Fortress, 2)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_fortify_colossus() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["fortify_colossus"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("fortify"):
		t0_res = by_id["fortify"]
	else:
		t0_res = _make_trait_stub("fortify", 5, "Block", 3)
	if by_id.has("colossus"):
		t1_res = by_id["colossus"]
	else:
		t1_res = _make_trait_stub("colossus", 5, "Buff", 3)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Block(10) + Buff(Titan, 3)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_bone_shield_ossify() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["bone_shield_ossify"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("bone_shield"):
		t0_res = by_id["bone_shield"]
	else:
		t0_res = _make_trait_stub("bone_shield", 5, "Block", 3)
	if by_id.has("ossify"):
		t1_res = by_id["ossify"]
	else:
		t1_res = _make_trait_stub("ossify", 5, "Block", 2)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Block(8) + Apply(Ossify, 2)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_void_null_convergence() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["void_null_convergence"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("void_rift"):
		t0_res = by_id["void_rift"]
	else:
		t0_res = _make_trait_stub("void_rift", 0, "Damage", 5)
	if by_id.has("null_touch"):
		t1_res = by_id["null_touch"]
	else:
		t1_res = _make_trait_stub("null_touch", 0, "Apply", 2)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Damage(12, Void) + Apply(Nullify, 3)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_void_end_mantle() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["void_end_mantle"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("void_end"):
		t0_res = by_id["void_end"]
	else:
		t0_res = _make_trait_stub("void_end", 6, "HealSelfPercent", 3)
	if by_id.has("void_mantle"):
		t1_res = by_id["void_mantle"]
	else:
		t1_res = _make_trait_stub("void_mantle", 6, "Block", 4)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 6, card)  # EndTurn
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("HealSelf(10%) + Block(8)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_rib_bone_draw_surge() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["rib_bone_draw_surge"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("rib_cage"):
		t0_res = by_id["rib_cage"]
	else:
		t0_res = _make_trait_stub("rib_cage", 6, "Block", 4)
	if by_id.has("bone_draw"):
		t1_res = by_id["bone_draw"]
	else:
		t1_res = _make_trait_stub("bone_draw", 6, "Spawn", 1)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 6, card)  # EndTurn
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Block(10) + Spawn(BoneCard, 2)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_bone_echo_chain() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["bone_echo_chain"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("bone_echo"):
		t0_res = by_id["bone_echo"]
	else:
		t0_res = _make_trait_stub("bone_echo", 3, "Block", 4)
	if by_id.has("skeletal_surge"):
		t1_res = by_id["skeletal_surge"]
	else:
		t1_res = _make_trait_stub("skeletal_surge", 3, "Spawn", 2)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Block(10) + Spawn(BoneCard, 2)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_void_echo_draw() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["void_echo_draw"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("void_echo"):
		t0_res = by_id["void_echo"]
	else:
		t0_res = _make_trait_stub("void_echo", 7, "Draw", 1)
	if by_id.has("void_draw"):
		t1_res = by_id["void_draw"]
	else:
		t1_res = _make_trait_stub("void_draw", 7, "HealSelfPercent", 2)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 7, card)  # OnTraitFired
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Draw(2) + HealSelf(6%)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_fire_surge_draw() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["fire_surge_draw"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("fire_surge"):
		t0_res = by_id["fire_surge"]
	else:
		t0_res = _make_trait_stub("fire_surge", 5, "Buff", 2)
	if by_id.has("inferno_draw"):
		t1_res = by_id["inferno_draw"]
	else:
		t1_res = _make_trait_stub("inferno_draw", 5, "Damage", 2)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Buff(Fire, 4) + Damage(3, Fire)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_moon_iron_tidal_guard() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["moon_iron_tidal_guard"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("moonbeam"):
		t0_res = by_id["moonbeam"]
	else:
		t0_res = _make_trait_stub("moonbeam", 4, "HealSelfPercent", 3)
	if by_id.has("steel_hide"):
		t1_res = by_id["steel_hide"]
	else:
		t1_res = _make_trait_stub("steel_hide", 4, "Block", 2)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 4, card)  # OnHit
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("HealSelf(8%) + Block(6)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_decay_void_annihilate() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["decay_void_annihilate"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("venomous_aura"):
		t0_res = by_id["venomous_aura"]
	else:
		t0_res = _make_trait_stub("venomous_aura", 3, "Apply", 3)
	if by_id.has("void_harvest"):
		t1_res = by_id["void_harvest"]
	else:
		t1_res = _make_trait_stub("void_harvest", 3, "HealSelfPercent", 8)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Apply(Venom, 5) + HealSelf(12%)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_decay_moon_inhibit() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["decay_moon_inhibit"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("decompose"):
		t0_res = by_id["decompose"]
	else:
		t0_res = _make_trait_stub("decompose", 7, "Apply", 2)
	if by_id.has("lunar_resonance"):
		t1_res = by_id["lunar_resonance"]
	else:
		t1_res = _make_trait_stub("lunar_resonance", 7, "HealSelfPercent", 4)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 7, card)  # OnTraitFired
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Apply(Stasis, 1)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")

func test_reaction_iron_resonance_guard() -> void:
	var by_id := _load_traits_by_id()
	var rx_by_id := _load_reactions_by_id()
	# Load the reaction
	var reaction: Resource = rx_by_id["iron_resonance_guard"]
	assert_that(reaction).is_not_null()
	# Build stubs for watch_for traits at the reaction timing so the reaction fires
	var t0_res: Resource
	var t1_res: Resource
	if by_id.has("iron_resonance"):
		t0_res = by_id["iron_resonance"]
	else:
		t0_res = _make_trait_stub("iron_resonance", 1, "Block", 3)
	if by_id.has("iron_draw"):
		t1_res = by_id["iron_draw"]
	else:
		t1_res = _make_trait_stub("iron_draw", 1, "Block", 2)
	# Card has both watch_for traits
	var card := _make_card2(t0_res, t1_res)
	var state := BattleStateScript.new()
	state.reactions = [reaction]
	var emitter := EmitScript.new()
	emitter.emit(state, 1, card)  # OnDraw
	# Reaction fires and returns early 鈥?exactly 1 log entry
	assert_int(state.trait_fire_log.size()).is_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source"]).is_equal("reaction")
	assert_str(entry["effect_type"]).is_equal("Block(8) + Buff(IronWill, 2)")
	# Parent trait default effects were NOT logged (no source=="trait" entries)
	for e in state.trait_fire_log:
		assert_str(e["source"]).is_not_equal("trait")
