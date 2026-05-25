## ISSUE-018b — UnlockPopup: a transient toast that animates a single new
## unlock. Used by both DeathScreen and WinScreen to draw player attention to
## newly granted content without forcing them to read the full list.
##
## Public API:
##   show_unlock(kind, id, display, locale)
##
## Animation: fade-in over 0.3s, hold 1.6s, fade-out over 0.4s, then queue_free.
extends Control

@onready var _panel: Panel  = $Panel
@onready var _kind: Label   = $Panel/V/Kind
@onready var _name: Label   = $Panel/V/Name


func _ready() -> void:
	modulate = Color(1, 1, 1, 0)


func show_unlock(kind: String, id: String, display: String, locale: String = "zh_CN") -> void:
	_kind.text = _kind_text(kind, locale)
	_name.text = display if not display.is_empty() else id
	var tw: Tween = create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.6)
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func _kind_text(kind: String, locale: String) -> String:
	if locale != "zh_CN":
		return "Unlocked: " + kind.capitalize()
	match kind:
		"trait":  return "解锁词条"
		"base":   return "解锁基底"
		"witch":  return "解锁巫师"
		"lore":   return "解锁传说"
		_: return "解锁"
