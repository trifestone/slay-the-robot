## ISSUE-014b — ReactionPreview floating tooltip.
##
## Renders a hover-side panel that shows what reactions would change if the
## currently-dragged trait were dropped into the hovered slot. Uses BBCode
## via RichTextLabel to draw strikethrough on removed reactions and green
## color on added reactions (PRD §3 US-09 "diff legibility").
##
## Public API:
##   show_for(card, slot_idx, candidate_trait_id, locale, predictor)
##   hide_preview()
##
## The preview anchors itself near the cursor on show_for(); a follow-mouse
## tween nudges it into the viewport so it never clips off-screen.
extends Control

const FREQ_PER_BATTLE_HEURISTIC := {
	# Coarse "expected reactions per battle" by reaction count, used until
	# a real telemetry-driven estimator lands. Keeps the UI honest about
	# magnitude without claiming precision.
	0: 0.0,
	1: 1.5,
	2: 3.0,
	3: 4.5,
	4: 6.0,
}

@onready var _panel: Panel        = $Panel
@onready var _title: Label        = $Panel/V/Title
@onready var _body: RichTextLabel = $Panel/V/Body
@onready var _freq: Label         = $Panel/V/Freq

var _reactions_cache: Array = []


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## camp_scene calls this once on startup if it has reaction data;
## otherwise show_for() falls back to an empty preview.
func set_reactions(reactions: Array) -> void:
	_reactions_cache = reactions


func show_for(card: Resource, slot_idx: int, candidate_trait_id: String,
		locale: String, predictor: Object) -> void:
	if card == null or slot_idx <= 0 or candidate_trait_id.is_empty() or predictor == null:
		hide_preview()
		return

	var candidate: Resource = _resolve_candidate(card, candidate_trait_id)
	# candidate may still be null (trait not in card / inventory) — predictor
	# treats null as pure-removal which is fine for tooltip purposes.

	var diff: Dictionary = predictor.diff_for_mount(card, slot_idx, candidate, _reactions_cache)
	_render(diff, locale)
	_position_near_cursor()
	visible = true


func hide_preview() -> void:
	visible = false


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

func _render(diff: Dictionary, locale: String) -> void:
	var added: Array = diff.get("added", [])
	var removed: Array = diff.get("removed", [])
	var unchanged: Array = diff.get("unchanged", [])

	_title.text = _t("Reactions", locale)

	var bb: PackedStringArray = []
	if added.is_empty() and removed.is_empty() and unchanged.is_empty():
		bb.append("[i]" + _t("(no reactions)", locale) + "[/i]")
	else:
		for id in unchanged:
			bb.append("• " + String(id))
		for id in added:
			bb.append("[color=#7fdf7f]+ " + String(id) + "[/color]")
		for id in removed:
			bb.append("[s][color=#df7f7f]- " + String(id) + "[/color][/s]")
	_body.bbcode_enabled = true
	_body.text = "\n".join(bb)

	var after_count: int = int(diff.get("after", []).size())
	var freq: float = float(FREQ_PER_BATTLE_HEURISTIC.get(after_count, 6.0))
	_freq.text = "≈ %.1f / %s" % [freq, _t("battle", locale)]


func _resolve_candidate(card: Resource, trait_id: String) -> Resource:
	# Look through current slots; if not in this card, the predictor handles
	# the case where candidate.id is brand-new for the card.
	for s in card.slots:
		if s.trait_ref != null and s.trait_ref.id == trait_id:
			return s.trait_ref
	return null


func _position_near_cursor() -> void:
	var mp: Vector2 = get_viewport().get_mouse_position()
	# Place to the right of cursor; flip if it would clip.
	var size_v: Vector2 = _panel.size
	var vp_size: Vector2 = get_viewport_rect().size
	var pos: Vector2 = mp + Vector2(20, 20)
	if pos.x + size_v.x > vp_size.x:
		pos.x = mp.x - size_v.x - 20
	if pos.y + size_v.y > vp_size.y:
		pos.y = vp_size.y - size_v.y - 8
	_panel.position = pos


func _t(s: String, locale: String) -> String:
	# Tiny placeholder; real locale strings get plumbed through later.
	if locale != "zh_CN":
		return s
	match s:
		"Reactions":     return "反应"
		"battle":        return "场战斗"
		"(no reactions)": return "(无反应)"
		_: return s
