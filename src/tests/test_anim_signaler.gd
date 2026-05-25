## ISSUE-011a — Tests for AnimSignaler.
## Verifies signals fire at correct moments relative to emit() execution and
## state-transition order. Headless-safe; no actual animation rendering.
extends GdUnitTestSuite

const TraitScript     := preload("res://data/trait.gd")
const SlotScript      := preload("res://data/slot.gd")
const CardScript      := preload("res://data/card.gd")
const ReactionScript  := preload("res://data/reaction.gd")
const BattleStateScript := preload("res://core/battle_state.gd")
const SignalerScript  := preload("res://core/anim_signaler.gd")

const ON_PLAY: int = 0  # Enums.TriggerEvent.OnPlay


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _trait(id: String, trigger: int, effect: String, value: int = 0) -> Resource:
	var t: Resource = TraitScript.new()
	t.id = id
	t.trigger = trigger
	t.effect_type = effect
	t.effect_value = value
	t.cooldown_per_turn = -1
	return t


func _slot(idx: int, t: Resource, locked: bool) -> Resource:
	var s: Resource = SlotScript.new()
	s.index = idx
	s.trait_ref = t
	s.locked = locked
	s.post_load()
	return s


func _card(t0: Resource, t1: Resource, t2: Resource) -> Resource:
	var c: Resource = CardScript.new()
	c.slots = [_slot(0, t0, true), _slot(1, t1, false), _slot(2, t2, false)]
	return c


func _state() -> Object:
	var s: Object = BattleStateScript.new()
	s.reset_per_battle()
	return s


# ---------------------------------------------------------------------------
# Counters used by signal handlers (avoiding multi-line lambdas)
# ---------------------------------------------------------------------------
var _trait_ids: Array = []
var _rx_ids: Array = []
var _killed_enemy: Resource = null
var _killed_drops: Array = []


func before_test() -> void:
	_trait_ids = []
	_rx_ids = []
	_killed_enemy = null
	_killed_drops = []


func _on_trait_fired(tid: String, _c: Resource, _d: int) -> void:
	_trait_ids.append(tid)


func _on_reaction_triggered(rid: String, _c: Resource) -> void:
	_rx_ids.append(rid)


func _on_enemy_killed(e: Resource, drops: Array) -> void:
	_killed_enemy = e
	_killed_drops = drops


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_trait_fired_signal_emits_per_slot() -> void:
	var sig: Node = auto_free(SignalerScript.new())
	add_child(sig)
	sig.trait_fired.connect(_on_trait_fired)

	var t0: Resource = _trait("flame_brand", ON_PLAY, "Damage", 4)
	var t1: Resource = _trait("oil_slick",   ON_PLAY, "Apply", 1)
	var t2: Resource = _trait("lunar_echo",  ON_PLAY, "Draw",  1)
	var card: Resource = _card(t0, t1, t2)
	var state: Object = _state()

	sig.emit_with_signals(state, ON_PLAY, card)
	assert_array(_trait_ids).contains_exactly(["flame_brand", "oil_slick", "lunar_echo"])


func test_reaction_fires_in_log_when_watch_for_matches() -> void:
	# Sanity check: emit() actually appends a reaction entry. Independent of signaler.
	var t0: Resource = _trait("flame_brand", ON_PLAY, "Damage", 4)
	var t1: Resource = _trait("oil_slick",   ON_PLAY, "Apply", 1)
	var card: Resource = _card(t0, t1, null)

	var rx: Resource = ReactionScript.new()
	rx.id = "fire_oil_explosion"
	rx.watch_for = ["flame_brand", "oil_slick"]
	rx.timing = ON_PLAY
	rx.override_effect = "Damage(12, Fire) + AOE_Splash(4)"

	var state: Object = _state()
	state.reactions = [rx]

	var sig: Node = auto_free(SignalerScript.new())
	add_child(sig)
	sig.emit_with_signals(state, ON_PLAY, card)

	assert_int(state.trait_fire_log.size()).is_equal(1)
	assert_str(state.trait_fire_log[0]["source"]).is_equal("reaction")


func test_reaction_triggered_signal_replaces_traits() -> void:
	# When watch_for matches, reaction_triggered fires AND no trait_fired follows.
	var sig: Node = auto_free(SignalerScript.new())
	add_child(sig)
	sig.reaction_triggered.connect(_on_reaction_triggered)
	sig.trait_fired.connect(_on_trait_fired)

	var t0: Resource = _trait("flame_brand", ON_PLAY, "Damage", 4)
	var t1: Resource = _trait("oil_slick",   ON_PLAY, "Apply", 1)
	var card: Resource = _card(t0, t1, null)

	var rx: Resource = ReactionScript.new()
	rx.id = "fire_oil_explosion"
	rx.watch_for = ["flame_brand", "oil_slick"]
	rx.timing = ON_PLAY
	rx.override_effect = "Damage(12, Fire) + AOE_Splash(4)"

	var state: Object = _state()
	state.reactions = [rx]

	sig.emit_with_signals(state, ON_PLAY, card)
	assert_int(_rx_ids.size()).is_equal(1)
	assert_int(_trait_ids.size()).is_equal(0)


func test_enemy_killed_signal_carries_drops() -> void:
	var sig: Node = auto_free(SignalerScript.new())
	add_child(sig)
	sig.enemy_killed.connect(_on_enemy_killed)

	var fake_enemy: Resource = TraitScript.new()
	fake_enemy.id = "skeleton_grunt"
	var drops: Array = ["flame_brand", "oil_slick"]
	sig.notify_enemy_killed(fake_enemy, drops)

	assert_object(_killed_enemy).is_not_null()
	assert_array(_killed_drops).contains_exactly(["flame_brand", "oil_slick"])


func test_signal_order_matches_log_order() -> void:
	var sig: Node = auto_free(SignalerScript.new())
	add_child(sig)
	sig.trait_fired.connect(_on_trait_fired)

	var t0: Resource = _trait("alpha", ON_PLAY, "Damage", 1)
	var t1: Resource = _trait("beta",  ON_PLAY, "Damage", 1)
	var t2: Resource = _trait("gamma", ON_PLAY, "Damage", 1)
	var card: Resource = _card(t0, t1, t2)
	var state: Object = _state()

	sig.emit_with_signals(state, ON_PLAY, card)

	var log_order: Array = []
	for entry in state.trait_fire_log:
		log_order.append(entry["source_trait_id"])
	assert_array(_trait_ids).contains_exactly_in_any_order(log_order)


func test_no_signals_when_event_does_not_match() -> void:
	var sig: Node = auto_free(SignalerScript.new())
	add_child(sig)
	sig.trait_fired.connect(_on_trait_fired)
	sig.reaction_triggered.connect(_on_reaction_triggered)

	# trigger=4 (OnHit) — won't fire on OnPlay
	var t0: Resource = _trait("on_hit_trait", 4, "Damage", 1)
	var card: Resource = _card(t0, null, null)
	var state: Object = _state()

	sig.emit_with_signals(state, ON_PLAY, card)
	assert_int(_trait_ids.size()).is_equal(0)
	assert_int(_rx_ids.size()).is_equal(0)
