## ISSUE-015b — ShopItem: a single card/trait/heal entry in the shop.
##
## Three kinds: "card", "trait", "heal". The heal kind is fixed (50g + 30%
## maxHP, PRD §4.8); card/trait kinds receive their id + display + cost from
## the shop scene's roll.
##
## Public API:
##   bind(kind, id, display, cost, locale)
##   set_sold_out(bool)
##
## Signals:
##   purchase_requested(kind, id)        # kind ∈ {"card","trait","heal"}
extends Control

signal purchase_requested(kind: String, id: String)

@onready var _frame: ColorRect    = $Frame
@onready var _name: Label         = $V/Name
@onready var _kind_label: Label   = $V/Kind
@onready var _cost_label: Label   = $V/Cost
@onready var _buy_btn: Button     = $V/BuyBtn

var _kind: String = ""
var _id: String = ""
var _sold_out: bool = false


func _ready() -> void:
	_buy_btn.pressed.connect(_on_buy_pressed)


func bind(kind: String, id: String, display: String, cost: int, locale: String = "zh_CN") -> void:
	_kind = kind
	_id = id
	_name.text = display
	_kind_label.text = _kind_text(kind, locale)
	_cost_label.text = "%d %s" % [cost, _t("gold", locale)]
	_buy_btn.text = _t("Buy", locale)
	_frame.color = _color_for_kind(kind)
	_sold_out = false
	_buy_btn.disabled = false
	_buy_btn.modulate = Color(1, 1, 1, 1)


func set_sold_out(value: bool) -> void:
	_sold_out = value
	_buy_btn.disabled = value
	if value:
		_buy_btn.text = _t("Sold", "zh_CN")
		modulate = Color(0.6, 0.6, 0.6, 1)
	else:
		modulate = Color(1, 1, 1, 1)


func _on_buy_pressed() -> void:
	if _sold_out:
		return
	purchase_requested.emit(_kind, _id)


func _color_for_kind(kind: String) -> Color:
	match kind:
		"card":  return Color(0.18, 0.22, 0.30, 0.95)
		"trait": return Color(0.22, 0.18, 0.28, 0.95)
		"heal":  return Color(0.18, 0.28, 0.20, 0.95)
		_:       return Color(0.15, 0.15, 0.18, 0.95)


func _kind_text(kind: String, locale: String) -> String:
	if locale != "zh_CN":
		return kind.capitalize()
	match kind:
		"card":  return "卡牌"
		"trait": return "词条"
		"heal":  return "治疗"
		_: return kind


func _t(s: String, locale: String) -> String:
	if locale != "zh_CN":
		return s
	match s:
		"gold": return "金"
		"Buy":  return "购买"
		"Sold": return "已售"
		_: return s
