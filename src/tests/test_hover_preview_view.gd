## ISSUE-012b — Tests for HoverPreviewView scene + 300ms hover delay.
## Verifies show/hide gating, step rendering, damage label, and timer behavior.
extends GdUnitTestSuite

const HoverPreviewScene := preload("res://ui/hover_preview.tscn")

const TraitScript      := preload("res://data/trait.gd")
const SlotScript       := preload("res://data/slot.gd")
const CardScript       := preload("res://data/card.gd")
const ReactionScript   := preload("res://data/reaction.gd")
const BattleStateScript := preload("res://core/battle_state.gd")

const ON_PLAY: int = 0


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
# Tests
# ---------------------------------------------------------------------------

func test_hover_preview_instantiates_hidden() -> void:
	var view: Control = auto_free(HoverPreviewScene.instantiate())
	add_child(view)
	# Should be hidden until shown
	assert_bool(view.visible).is_false()


func test_show_for_renders_step_list_and_damage() -> void:
	var view: Control = auto_free(HoverPreviewScene.instantiate())
	add_child(view)
	var t0: Resource = _trait("alpha", ON_PLAY, "Damage", 4)
	var t1: Resource = _trait("beta",  ON_PLAY, "Damage", 3)
	var card: Resource = _card(t0, t1, null)

	view.show_for(card, _state(), Vector2(120, 80))
	assert_bool(view.visible).is_true()
	assert_int(view.get_step_count()).is_equal(2)
	assert_str(view.get_damage_text()).contains("7")


func test_show_for_with_reaction_marks_override() -> void:
	# US-04 + US-03 alignment: reaction step must be visually distinct.
	var view: Control = auto_free(HoverPreviewScene.instantiate())
	add_child(view)

	var t0: Resource = _trait("flame_brand", ON_PLAY, "Damage", 4)
	var t1: Resource = _trait("oil_slick",   ON_PLAY, "Apply",  1)
	var card: Resource = _card(t0, t1, null)

	var rx: Resource = ReactionScript.new()
	rx.id = "fire_oil_explosion"
	rx.watch_for = ["flame_brand", "oil_slick"]
	rx.timing = ON_PLAY
	rx.override_effect = "Damage(12, Fire)"

	var state: Object = _state()
	state.reactions = [rx]

	view.show_for(card, state, Vector2.ZERO)
	assert_int(view.get_step_count()).is_equal(1)
	assert_str(view.get_damage_text()).contains("12")


func test_hide_preview_hides_and_clears_pending() -> void:
	var view: Control = auto_free(HoverPreviewScene.instantiate())
	add_child(view)
	var t0: Resource = _trait("alpha", ON_PLAY, "Damage", 4)
	var card: Resource = _card(t0, null, null)
	view.show_for(card, _state(), Vector2.ZERO)
	assert_bool(view.visible).is_true()
	view.hide_preview()
	assert_bool(view.visible).is_false()


func test_begin_hover_marks_pending() -> void:
	# US-04 spec: 300ms dwell — view should be pending but not visible yet.
	var view: Control = auto_free(HoverPreviewScene.instantiate())
	add_child(view)
	view.set_hover_delay_ms(300)

	var t0: Resource = _trait("alpha", ON_PLAY, "Damage", 4)
	var card: Resource = _card(t0, null, null)
	view.begin_hover(card, _state(), Vector2.ZERO)
	assert_bool(view.is_pending()).is_true()
	assert_bool(view.visible).is_false()


func test_cancel_hover_stops_pending_show() -> void:
	var view: Control = auto_free(HoverPreviewScene.instantiate())
	add_child(view)
	view.set_hover_delay_ms(300)
	var t0: Resource = _trait("alpha", ON_PLAY, "Damage", 4)
	var card: Resource = _card(t0, null, null)
	view.begin_hover(card, _state(), Vector2.ZERO)
	assert_bool(view.is_pending()).is_true()

	view.cancel_hover()
	assert_bool(view.is_pending()).is_false()
	assert_bool(view.visible).is_false()


func test_short_delay_shows_after_timeout() -> void:
	# Use a 1ms delay so we can wait deterministically.
	var view: Control = auto_free(HoverPreviewScene.instantiate())
	add_child(view)
	view.set_hover_delay_ms(1)

	var t0: Resource = _trait("alpha", ON_PLAY, "Damage", 6)
	var card: Resource = _card(t0, null, null)
	view.begin_hover(card, _state(), Vector2(50, 60))
	# Wait long enough for the 1ms timer to fire
	await get_tree().create_timer(0.1).timeout
	assert_bool(view.visible).is_true()
	assert_int(view.get_step_count()).is_equal(1)
	assert_str(view.get_damage_text()).contains("6")


func test_anchor_position_applied() -> void:
	var view: Control = auto_free(HoverPreviewScene.instantiate())
	add_child(view)
	var t0: Resource = _trait("alpha", ON_PLAY, "Damage", 4)
	var card: Resource = _card(t0, null, null)
	view.show_for(card, _state(), Vector2(123, 45))
	assert_int(int(view.position.x)).is_equal(123)
	assert_int(int(view.position.y)).is_equal(45)
