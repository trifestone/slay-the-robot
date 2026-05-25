## ISSUE-010b — IntentWidget Control: visual badge above an enemy showing
## next-turn intent (icon code + numeric label) with hover tooltip.
## Uses intent_widget.gd resolver for locale + numeric formatting.
extends Control

const IntentResolverScript := preload("res://ui/intent_widget.gd")

const WIDGET_SIZE := Vector2(80, 56)

@onready var _bg: ColorRect    = $Bg
@onready var _icon: Label      = $Icon
@onready var _label: Label     = $Label

var _resolver: Object = null
var _tooltip_text: String = ""


func _ready() -> void:
	custom_minimum_size = WIDGET_SIZE
	_resolver = IntentResolverScript.new()
	mouse_filter = MOUSE_FILTER_STOP


## Bind intent + value + locale, refresh visuals, set tooltip.
func bind(intent: String, value: int, locale: String = "zh_CN") -> void:
	var r: Dictionary = _resolver.resolve(intent, value, locale)
	_icon.text = r["icon_code"]
	_label.text = r["label"]
	_bg.color = r["color"]
	_tooltip_text = r["tooltip"]
	tooltip_text = _tooltip_text


## For tests: read back the rendered tooltip without TooltipController.
func get_tooltip_string() -> String:
	return _tooltip_text
