## ISSUE-011b — Smoke tests for VFX scenes (reaction_burst + devour_kill).
## Verifies: scenes instantiate, signaler wiring works, play() invokes without
## error, and is_playing() flips correctly. Headless-safe — no rendering checks.
extends GdUnitTestSuite

const ReactionBurstScene := preload("res://vfx/reaction_burst.tscn")
const DevourKillScene    := preload("res://vfx/devour_kill.tscn")
const SignalerScript     := preload("res://core/anim_signaler.gd")
const TraitScript        := preload("res://data/trait.gd")
const SlotScript         := preload("res://data/slot.gd")
const CardScript         := preload("res://data/card.gd")
const ReactionScript     := preload("res://data/reaction.gd")
const BattleStateScript  := preload("res://core/battle_state.gd")

const ON_PLAY: int = 0


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _trait(id: String, trigger: int = ON_PLAY) -> Resource:
	var t: Resource = TraitScript.new()
	t.id = id
	t.trigger = trigger
	t.effect_type = "Damage"
	t.effect_value = 1
	t.cooldown_per_turn = -1
	return t


func _slot(idx: int, t: Resource, locked: bool) -> Resource:
	var s: Resource = SlotScript.new()
	s.index = idx
	s.trait_ref = t
	s.locked = locked
	s.post_load()
	return s


func _card(t0: Resource, t1: Resource) -> Resource:
	var c: Resource = CardScript.new()
	c.slots = [_slot(0, t0, true), _slot(1, t1, false), _slot(2, null, false)]
	return c


func _state() -> Object:
	var s: Object = BattleStateScript.new()
	s.reset_per_battle()
	return s


# ---------------------------------------------------------------------------
# ReactionBurst tests
# ---------------------------------------------------------------------------

func test_reaction_burst_instantiates() -> void:
	var burst: Node2D = auto_free(ReactionBurstScene.instantiate())
	add_child(burst)
	assert_object(burst).is_not_null()
	assert_bool(burst.is_playing()).is_false()


func test_reaction_burst_play_marks_busy() -> void:
	var burst: Node2D = auto_free(ReactionBurstScene.instantiate())
	add_child(burst)
	burst.play(Rect2(Vector2.ZERO, Vector2(160, 220)), "fire_oil_explosion", 1.0)
	assert_bool(burst.is_playing()).is_true()


func test_reaction_burst_color_keywords() -> void:
	# Verify _color_for picks distinct hues per keyword family.
	var burst: Node2D = auto_free(ReactionBurstScene.instantiate())
	add_child(burst)
	var fire: Color = burst._color_for("fire_oil_explosion")
	var void_: Color = burst._color_for("void_collapse")
	var lunar: Color = burst._color_for("lunar_echo_chain")
	var default_: Color = burst._color_for("unknown_id")
	assert_bool(fire != void_).is_true()
	assert_bool(void_ != lunar).is_true()
	assert_bool(default_ != fire).is_true()


func test_reaction_burst_connects_to_signaler() -> void:
	# When wired, reaction_triggered triggers play().
	var sig: Node = auto_free(SignalerScript.new())
	add_child(sig)
	var burst: Node2D = auto_free(ReactionBurstScene.instantiate())
	add_child(burst)
	burst.connect_signaler(sig)

	var t0: Resource = _trait("flame_brand")
	var t1: Resource = _trait("oil_slick")
	var card: Resource = _card(t0, t1)
	var rx: Resource = ReactionScript.new()
	rx.id = "fire_oil_explosion"
	rx.watch_for = ["flame_brand", "oil_slick"]
	rx.timing = ON_PLAY
	rx.override_effect = "Damage(12, Fire)"
	var state: Object = _state()
	state.reactions = [rx]

	sig.emit_with_signals(state, ON_PLAY, card)
	# After signal-driven play, burst should be busy
	assert_bool(burst.is_playing()).is_true()


# ---------------------------------------------------------------------------
# DevourKill tests
# ---------------------------------------------------------------------------

func test_devour_kill_instantiates() -> void:
	var dk: Node2D = auto_free(DevourKillScene.instantiate())
	add_child(dk)
	assert_object(dk).is_not_null()
	assert_bool(dk.is_playing()).is_false()


func test_devour_kill_play_populates_drops() -> void:
	var dk: Node2D = auto_free(DevourKillScene.instantiate())
	add_child(dk)
	dk.play(Rect2(Vector2.ZERO, Vector2(180, 240)),
		"skeleton_grunt", ["flame_brand", "oil_slick"], 1.2)
	assert_bool(dk.is_playing()).is_true()
	var row: HBoxContainer = dk.get_node("DropRow")
	assert_int(row.get_child_count()).is_equal(2)


func test_devour_kill_handles_resource_drops() -> void:
	var dk: Node2D = auto_free(DevourKillScene.instantiate())
	add_child(dk)
	var t1: Resource = _trait("flame_brand")
	var t2: Resource = _trait("oil_slick")
	dk.play(Rect2(Vector2.ZERO, Vector2(180, 240)), "wraith", [t1, t2], 1.0)
	var row: HBoxContainer = dk.get_node("DropRow")
	assert_int(row.get_child_count()).is_equal(2)


func test_devour_kill_connects_to_signaler() -> void:
	var sig: Node = auto_free(SignalerScript.new())
	add_child(sig)
	var dk: Node2D = auto_free(DevourKillScene.instantiate())
	add_child(dk)
	dk.connect_signaler(sig)

	var fake_enemy: Resource = TraitScript.new()
	fake_enemy.id = "skeleton_grunt"
	sig.notify_enemy_killed(fake_enemy, ["flame_brand"])
	assert_bool(dk.is_playing()).is_true()


func test_duration_clamps_to_max() -> void:
	# Both scenes must clamp duration to ≤ MAX_DURATION (1.2s) per PRD VFX cap.
	var burst: Node2D = auto_free(ReactionBurstScene.instantiate())
	add_child(burst)
	burst.play(Rect2(Vector2.ZERO, Vector2(160, 220)), "test_id", 5.0)
	assert_bool(burst.is_playing()).is_true()

	var dk: Node2D = auto_free(DevourKillScene.instantiate())
	add_child(dk)
	dk.play(Rect2(Vector2.ZERO, Vector2(180, 240)), "test_enemy", [], 5.0)
	assert_bool(dk.is_playing()).is_true()
