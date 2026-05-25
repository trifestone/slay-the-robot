## GdUnit4 test suite for ISSUE-021: Trait coverage matrix.
## Parameterized over all 80 trait ids 鈥?one test function per trait.
## TODO: Add en locale .po file in a future ticket (zh-CN flavor only for now).
extends GdUnitTestSuite

const TraitScript      := preload("res://data/trait.gd")
const SlotScript       := preload("res://data/slot.gd")
const CardScript       := preload("res://data/card.gd")
const LoaderScript     := preload("res://data/loader.gd")
const BattleStateScript := preload("res://core/battle_state.gd")
const EmitScript       := preload("res://core/emit.gd")

const TRAITS_PATH := "res://data/traits.json"


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


## Build a card with one trait in slot 0.
func _make_card_single(t: Resource) -> Resource:
	var s0 = SlotScript.new()
	s0.index = 0
	s0.trait_ref = t
	s0.locked = true
	s0.post_load()
	var s1 = SlotScript.new()
	s1.index = 1
	s1.locked = false
	s1.post_load()
	var s2 = SlotScript.new()
	s2.index = 2
	s2.locked = false
	s2.post_load()
	var card = CardScript.new()
	card.slots = [s0, s1, s2]
	return card


## Build a card: slot0=OnPlay stub, slot1=OnTraitFired trait.
## Used for traits that trigger on OnTraitFired (trigger==7).
func _make_card_otf(onplay_stub: Resource, otf_trait: Resource) -> Resource:
	var s0 = SlotScript.new()
	s0.index = 0
	s0.trait_ref = onplay_stub
	s0.locked = true
	s0.post_load()
	var s1 = SlotScript.new()
	s1.index = 1
	s1.trait_ref = otf_trait
	s1.locked = false
	s1.post_load()
	var s2 = SlotScript.new()
	s2.index = 2
	s2.locked = false
	s2.post_load()
	var card = CardScript.new()
	card.slots = [s0, s1, s2]
	return card


func _make_stub_onplay(stub_id: String) -> Resource:
	var t = TraitScript.new()
	t.id = stub_id
	t.trigger = 0  # OnPlay
	t.effect_type = "Damage"
	t.effect_value = 1
	t.cooldown_per_turn = -1
	t.axis_timing = 0
	t.axis_scope = 0
	t.axis_school = 0
	t.rarity = 0
	t.removable = true
	t.flavor = ""
	return t


func test_trait_flame_brand() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["flame_brand"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("flame_brand")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(4)

func test_trait_oil_slick() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["oil_slick"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 4, card)  # OnHit
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("oil_slick")
	assert_str(entry["effect_type"]).is_equal("Apply")
	assert_int(entry["effect_value"]).is_equal(1)

func test_trait_bone_harvest() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["bone_harvest"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("bone_harvest")
	assert_str(entry["effect_type"]).is_equal("Spawn")
	assert_int(entry["effect_value"]).is_equal(1)

func test_trait_lunar_echo() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["lunar_echo"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 6, card)  # EndTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("lunar_echo")
	assert_str(entry["effect_type"]).is_equal("Draw")
	assert_int(entry["effect_value"]).is_equal(1)

func test_trait_void_consume() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["void_consume"]
	assert_that(trait_res).is_not_null()
	# OnTraitFired trait: use OTF helper card to fire via OnPlay bubble
	var stub := _make_stub_onplay("_stub_for_void_consume")
	var card := _make_card_otf(stub, trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay fires stub -> bubbles OnTraitFired
	# Find the log entry for this trait
	var found := false
	for entry in state.trait_fire_log:
		if entry["source_trait_id"] == "void_consume":
			assert_str(entry["effect_type"]).is_equal("HealSelfPercent")
			assert_int(entry["effect_value"]).is_equal(5)
			found = true
			break
	assert_bool(found).is_true()

func test_trait_ember_strike() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["ember_strike"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("ember_strike")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(3)

func test_trait_fire_surge() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["fire_surge"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("fire_surge")
	assert_str(entry["effect_type"]).is_equal("Buff")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_ignite_mark() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["ignite_mark"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 4, card)  # OnHit
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("ignite_mark")
	assert_str(entry["effect_type"]).is_equal("Apply")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_inferno_draw() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["inferno_draw"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 1, card)  # OnDraw
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("inferno_draw")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_flame_ward() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["flame_ward"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 6, card)  # EndTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("flame_ward")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(3)

func test_trait_scorch_pulse() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["scorch_pulse"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("scorch_pulse")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(6)

func test_trait_blaze_echo() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["blaze_echo"]
	assert_that(trait_res).is_not_null()
	# OnTraitFired trait: use OTF helper card to fire via OnPlay bubble
	var stub := _make_stub_onplay("_stub_for_blaze_echo")
	var card := _make_card_otf(stub, trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay fires stub -> bubbles OnTraitFired
	# Find the log entry for this trait
	var found := false
	for entry in state.trait_fire_log:
		if entry["source_trait_id"] == "blaze_echo":
			assert_str(entry["effect_type"]).is_equal("Damage")
			assert_int(entry["effect_value"]).is_equal(3)
			found = true
			break
	assert_bool(found).is_true()

func test_trait_cinder_burst() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["cinder_burst"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 2, card)  # OnDiscard
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("cinder_burst")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(4)

func test_trait_pyre_bloom() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["pyre_bloom"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("pyre_bloom")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(5)

func test_trait_fire_chain() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["fire_chain"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("fire_chain")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_char_mark() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["char_mark"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 2, card)  # OnDiscard
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("char_mark")
	assert_str(entry["effect_type"]).is_equal("Apply")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_rot_spore() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["rot_spore"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("rot_spore")
	assert_str(entry["effect_type"]).is_equal("Apply")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_plague_touch() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["plague_touch"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 4, card)  # OnHit
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("plague_touch")
	assert_str(entry["effect_type"]).is_equal("Apply")
	assert_int(entry["effect_value"]).is_equal(1)

func test_trait_mold_growth() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["mold_growth"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("mold_growth")
	assert_str(entry["effect_type"]).is_equal("Apply")
	assert_int(entry["effect_value"]).is_equal(1)

func test_trait_blight_draw() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["blight_draw"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 1, card)  # OnDraw
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("blight_draw")
	assert_str(entry["effect_type"]).is_equal("Apply")
	assert_int(entry["effect_value"]).is_equal(1)

func test_trait_decompose() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["decompose"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 6, card)  # EndTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("decompose")
	assert_str(entry["effect_type"]).is_equal("Apply")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_venomous_aura() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["venomous_aura"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("venomous_aura")
	assert_str(entry["effect_type"]).is_equal("Apply")
	assert_int(entry["effect_value"]).is_equal(3)

func test_trait_entropy_wave() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["entropy_wave"]
	assert_that(trait_res).is_not_null()
	# OnTraitFired trait: use OTF helper card to fire via OnPlay bubble
	var stub := _make_stub_onplay("_stub_for_entropy_wave")
	var card := _make_card_otf(stub, trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay fires stub -> bubbles OnTraitFired
	# Find the log entry for this trait
	var found := false
	for entry in state.trait_fire_log:
		if entry["source_trait_id"] == "entropy_wave":
			assert_str(entry["effect_type"]).is_equal("Apply")
			assert_int(entry["effect_value"]).is_equal(2)
			found = true
			break
	assert_bool(found).is_true()

func test_trait_putrid_bloom() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["putrid_bloom"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 2, card)  # OnDiscard
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("putrid_bloom")
	assert_str(entry["effect_type"]).is_equal("Apply")
	assert_int(entry["effect_value"]).is_equal(3)

func test_trait_necrotic_pulse() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["necrotic_pulse"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("necrotic_pulse")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_venom_touch() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["venom_touch"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 4, card)  # OnHit
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("venom_touch")
	assert_str(entry["effect_type"]).is_equal("Apply")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_miasma_cloud() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["miasma_cloud"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("miasma_cloud")
	assert_str(entry["effect_type"]).is_equal("Apply")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_decay_draw() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["decay_draw"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 1, card)  # OnDraw
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("decay_draw")
	assert_str(entry["effect_type"]).is_equal("Apply")
	assert_int(entry["effect_value"]).is_equal(1)

func test_trait_decay_burst() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["decay_burst"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("decay_burst")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(5)

func test_trait_blight_echo() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["blight_echo"]
	assert_that(trait_res).is_not_null()
	# OnTraitFired trait: use OTF helper card to fire via OnPlay bubble
	var stub := _make_stub_onplay("_stub_for_blight_echo")
	var card := _make_card_otf(stub, trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay fires stub -> bubbles OnTraitFired
	# Find the log entry for this trait
	var found := false
	for entry in state.trait_fire_log:
		if entry["source_trait_id"] == "blight_echo":
			assert_str(entry["effect_type"]).is_equal("Damage")
			assert_int(entry["effect_value"]).is_equal(2)
			found = true
			break
	assert_bool(found).is_true()

func test_trait_lunar_tide() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["lunar_tide"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("lunar_tide")
	assert_str(entry["effect_type"]).is_equal("Draw")
	assert_int(entry["effect_value"]).is_equal(1)

func test_trait_moonbeam() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["moonbeam"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 4, card)  # OnHit
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("moonbeam")
	assert_str(entry["effect_type"]).is_equal("HealSelfPercent")
	assert_int(entry["effect_value"]).is_equal(3)

func test_trait_crescent_guard() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["crescent_guard"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("crescent_guard")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(4)

func test_trait_silver_draw() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["silver_draw"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 1, card)  # OnDraw
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("silver_draw")
	assert_str(entry["effect_type"]).is_equal("Buff")
	assert_int(entry["effect_value"]).is_equal(1)

func test_trait_full_moon_surge() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["full_moon_surge"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 6, card)  # EndTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("full_moon_surge")
	assert_str(entry["effect_type"]).is_equal("Buff")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_moon_harvest() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["moon_harvest"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("moon_harvest")
	assert_str(entry["effect_type"]).is_equal("Draw")
	assert_int(entry["effect_value"]).is_equal(1)

func test_trait_lunar_resonance() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["lunar_resonance"]
	assert_that(trait_res).is_not_null()
	# OnTraitFired trait: use OTF helper card to fire via OnPlay bubble
	var stub := _make_stub_onplay("_stub_for_lunar_resonance")
	var card := _make_card_otf(stub, trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay fires stub -> bubbles OnTraitFired
	# Find the log entry for this trait
	var found := false
	for entry in state.trait_fire_log:
		if entry["source_trait_id"] == "lunar_resonance":
			assert_str(entry["effect_type"]).is_equal("HealSelfPercent")
			assert_int(entry["effect_value"]).is_equal(4)
			found = true
			break
	assert_bool(found).is_true()

func test_trait_moon_veil() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["moon_veil"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("moon_veil")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(6)

func test_trait_starfall() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["starfall"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("starfall")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(5)

func test_trait_purify_light() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["purify_light"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("purify_light")
	assert_str(entry["effect_type"]).is_equal("HealSelfPercent")
	assert_int(entry["effect_value"]).is_equal(6)

func test_trait_moon_strike() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["moon_strike"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 4, card)  # OnHit
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("moon_strike")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(4)

func test_trait_lunar_ward() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["lunar_ward"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 2, card)  # OnDiscard
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("lunar_ward")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(5)

func test_trait_lunar_kill() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["lunar_kill"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("lunar_kill")
	assert_str(entry["effect_type"]).is_equal("HealSelfPercent")
	assert_int(entry["effect_value"]).is_equal(10)

func test_trait_iron_bulwark() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["iron_bulwark"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 6, card)  # EndTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("iron_bulwark")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(5)

func test_trait_steel_fist() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["steel_fist"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("steel_fist")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(5)

func test_trait_iron_draw() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["iron_draw"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 1, card)  # OnDraw
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("iron_draw")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_counter_blow() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["counter_blow"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 4, card)  # OnHit
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("counter_blow")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(3)

func test_trait_fortify() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["fortify"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("fortify")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(3)

func test_trait_iron_crush() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["iron_crush"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("iron_crush")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(6)

func test_trait_hammer_discard() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["hammer_discard"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 2, card)  # OnDiscard
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("hammer_discard")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(5)

func test_trait_iron_resonance() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["iron_resonance"]
	assert_that(trait_res).is_not_null()
	# OnTraitFired trait: use OTF helper card to fire via OnPlay bubble
	var stub := _make_stub_onplay("_stub_for_iron_resonance")
	var card := _make_card_otf(stub, trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay fires stub -> bubbles OnTraitFired
	# Find the log entry for this trait
	var found := false
	for entry in state.trait_fire_log:
		if entry["source_trait_id"] == "iron_resonance":
			assert_str(entry["effect_type"]).is_equal("Block")
			assert_int(entry["effect_value"]).is_equal(3)
			found = true
			break
	assert_bool(found).is_true()

func test_trait_bastion() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["bastion"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 6, card)  # EndTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("bastion")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(8)

func test_trait_colossus() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["colossus"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("colossus")
	assert_str(entry["effect_type"]).is_equal("Buff")
	assert_int(entry["effect_value"]).is_equal(3)

func test_trait_steel_hide() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["steel_hide"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 4, card)  # OnHit
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("steel_hide")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_iron_veil() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["iron_veil"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 1, card)  # OnDraw
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("iron_veil")
	assert_str(entry["effect_type"]).is_equal("Buff")
	assert_int(entry["effect_value"]).is_equal(1)

func test_trait_iron_spike() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["iron_spike"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("iron_spike")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(8)

func test_trait_iron_discard() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["iron_discard"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 2, card)  # OnDiscard
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("iron_discard")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(4)

func test_trait_bone_shield() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["bone_shield"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("bone_shield")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(3)

func test_trait_marrow_drain() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["marrow_drain"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 4, card)  # OnHit
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("marrow_drain")
	assert_str(entry["effect_type"]).is_equal("HealSelfPercent")
	assert_int(entry["effect_value"]).is_equal(4)

func test_trait_ossify() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["ossify"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("ossify")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_bone_draw() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["bone_draw"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 1, card)  # OnDraw
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("bone_draw")
	assert_str(entry["effect_type"]).is_equal("Spawn")
	assert_int(entry["effect_value"]).is_equal(1)

func test_trait_rib_cage() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["rib_cage"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 6, card)  # EndTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("rib_cage")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(4)

func test_trait_skeletal_surge() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["skeletal_surge"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("skeletal_surge")
	assert_str(entry["effect_type"]).is_equal("Spawn")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_bone_echo() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["bone_echo"]
	assert_that(trait_res).is_not_null()
	# OnTraitFired trait: use OTF helper card to fire via OnPlay bubble
	var stub := _make_stub_onplay("_stub_for_bone_echo")
	var card := _make_card_otf(stub, trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay fires stub -> bubbles OnTraitFired
	# Find the log entry for this trait
	var found := false
	for entry in state.trait_fire_log:
		if entry["source_trait_id"] == "bone_echo":
			assert_str(entry["effect_type"]).is_equal("Block")
			assert_int(entry["effect_value"]).is_equal(4)
			found = true
			break
	assert_bool(found).is_true()

func test_trait_bone_splinter() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["bone_splinter"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 2, card)  # OnDiscard
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("bone_splinter")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(3)

func test_trait_necro_surge() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["necro_surge"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("necro_surge")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(6)

func test_trait_bone_storm() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["bone_storm"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("bone_storm")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(3)

func test_trait_bone_strike() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["bone_strike"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 4, card)  # OnHit
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("bone_strike")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(3)

func test_trait_void_rift() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["void_rift"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("void_rift")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(5)

func test_trait_void_draw() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["void_draw"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 1, card)  # OnDraw
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("void_draw")
	assert_str(entry["effect_type"]).is_equal("HealSelfPercent")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_null_touch() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["null_touch"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 4, card)  # OnHit
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("null_touch")
	assert_str(entry["effect_type"]).is_equal("Apply")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_void_mantle() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["void_mantle"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 5, card)  # StartTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("void_mantle")
	assert_str(entry["effect_type"]).is_equal("Block")
	assert_int(entry["effect_value"]).is_equal(4)

func test_trait_void_end() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["void_end"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 6, card)  # EndTurn
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("void_end")
	assert_str(entry["effect_type"]).is_equal("HealSelfPercent")
	assert_int(entry["effect_value"]).is_equal(3)

func test_trait_void_harvest() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["void_harvest"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("void_harvest")
	assert_str(entry["effect_type"]).is_equal("HealSelfPercent")
	assert_int(entry["effect_value"]).is_equal(8)

func test_trait_null_field() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["null_field"]
	assert_that(trait_res).is_not_null()
	# OnTraitFired trait: use OTF helper card to fire via OnPlay bubble
	var stub := _make_stub_onplay("_stub_for_null_field")
	var card := _make_card_otf(stub, trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay fires stub -> bubbles OnTraitFired
	# Find the log entry for this trait
	var found := false
	for entry in state.trait_fire_log:
		if entry["source_trait_id"] == "null_field":
			assert_str(entry["effect_type"]).is_equal("Buff")
			assert_int(entry["effect_value"]).is_equal(2)
			found = true
			break
	assert_bool(found).is_true()

func test_trait_abyss_surge() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["abyss_surge"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 2, card)  # OnDiscard
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("abyss_surge")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(6)

func test_trait_void_shard() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["void_shard"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("void_shard")
	assert_str(entry["effect_type"]).is_equal("Buff")
	assert_int(entry["effect_value"]).is_equal(2)

func test_trait_oblivion_core() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["oblivion_core"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("oblivion_core")
	assert_str(entry["effect_type"]).is_equal("Damage")
	assert_int(entry["effect_value"]).is_equal(10)

func test_trait_void_echo() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["void_echo"]
	assert_that(trait_res).is_not_null()
	# OnTraitFired trait: use OTF helper card to fire via OnPlay bubble
	var stub := _make_stub_onplay("_stub_for_void_echo")
	var card := _make_card_otf(stub, trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 0, card)  # OnPlay fires stub -> bubbles OnTraitFired
	# Find the log entry for this trait
	var found := false
	for entry in state.trait_fire_log:
		if entry["source_trait_id"] == "void_echo":
			assert_str(entry["effect_type"]).is_equal("Draw")
			assert_int(entry["effect_value"]).is_equal(1)
			found = true
			break
	assert_bool(found).is_true()

func test_trait_void_kill() -> void:
	var by_id := _load_traits_by_id()
	var trait_res: Resource = by_id["void_kill"]
	assert_that(trait_res).is_not_null()
	var card := _make_card_single(trait_res)
	var state := BattleStateScript.new()
	var emitter := EmitScript.new()
	emitter.emit(state, 3, card)  # OnKill
	assert_int(state.trait_fire_log.size()).is_greater_equal(1)
	var entry: Dictionary = state.trait_fire_log[0]
	assert_str(entry["source_trait_id"]).is_equal("void_kill")
	assert_str(entry["effect_type"]).is_equal("Draw")
	assert_int(entry["effect_value"]).is_equal(1)
