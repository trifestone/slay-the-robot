## ISSUE-018b — DeathScreen: shown when run ends without winning.
##
## Renders run summary (battles_won, gold collected, traits collected),
## fires unlock popups for any new entries the meta system granted, and
## offers a "Return to Menu" button.
##
## Public API:
##   show_for(run_state, meta_delta, locale)
##     run_state: Resource (RunState)
##     meta_delta: Dictionary returned by meta_state.apply_run_result()
##
## Signals:
##   return_requested()
extends Control

signal return_requested()

@onready var _title: Label        = $V/Title
@onready var _summary: RichTextLabel = $V/Summary
@onready var _unlocks: VBoxContainer = $V/UnlocksList
@onready var _return_btn: Button  = $V/ReturnBtn


func _ready() -> void:
	_return_btn.pressed.connect(_on_return_pressed)


func show_for(run_state: Resource, meta_delta: Dictionary, locale: String = "zh_CN") -> void:
	_title.text = _t("Defeat", locale)

	_summary.bbcode_enabled = true
	_summary.text = _build_summary(run_state, meta_delta, locale)

	_render_unlocks(meta_delta, locale)
	visible = true


func _build_summary(run_state: Resource, meta_delta: Dictionary, locale: String) -> String:
	var battles: int = int(run_state.get("battles_won")) if run_state.has_method("get") else 0
	var traits: int = 0
	if run_state.has_method("get") and run_state.get("traits_collected") != null:
		traits = int(run_state.get("traits_collected").size())
	var xp: int = int(meta_delta.get("xp_gained", 0))

	var lines: PackedStringArray = []
	lines.append("[b]" + _t("Battles won", locale) + "[/b]: %d" % battles)
	lines.append("[b]" + _t("Traits collected", locale) + "[/b]: %d" % traits)
	lines.append("[b]" + _t("XP gained", locale) + "[/b]: %d" % xp)
	return "\n".join(lines)


func _render_unlocks(meta_delta: Dictionary, locale: String) -> void:
	for c in _unlocks.get_children():
		c.queue_free()
	var entries: Array = meta_delta.get("new_unlocks", [])
	if entries.is_empty():
		var none: Label = Label.new()
		none.text = _t("(no new unlocks)", locale)
		none.modulate = Color(0.7, 0.7, 0.7, 1)
		_unlocks.add_child(none)
		return
	var header: Label = Label.new()
	header.text = _t("Unlocked", locale)
	header.modulate = Color(1, 0.95, 0.7, 1)
	_unlocks.add_child(header)
	for u in entries:
		var l: Label = Label.new()
		l.text = "✦ %s — %s" % [String(u.get("kind", "")), String(u.get("id", ""))]
		_unlocks.add_child(l)


func _on_return_pressed() -> void:
	visible = false
	return_requested.emit()


func _t(s: String, locale: String) -> String:
	if locale != "zh_CN":
		return s
	match s:
		"Defeat":           return "败北"
		"Battles won":      return "战斗胜利"
		"Traits collected": return "收集词条"
		"XP gained":        return "经验"
		"(no new unlocks)": return "(暂无新解锁)"
		"Unlocked":         return "解锁"
		"Return to Menu":   return "返回菜单"
		_: return s
