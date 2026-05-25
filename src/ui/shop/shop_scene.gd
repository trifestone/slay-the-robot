## ISSUE-015b — ShopScene: two-column shop view (cards | traits) plus heal.
##
## The scene is data-driven via `setup(run_state, offers, locale)`:
##   offers = {
##     "cards":  [{id, display, cost}, ...],   # PRD §4.8 50/80/140g
##     "traits": [{id, display, cost}, ...],   # PRD §4.8 40/70/120g
##     "heal":   {cost: 50},                   # 30% maxHP
##   }
##
## Each ShopItem emits purchase_requested(kind, id); ShopScene routes to
## core/shop_state.gd and applies the result to run_state in place.
## Sold-out items stay visible but disabled.
##
## Signals out:
##   leave_requested()
extends Control

const ShopItemScene := preload("res://ui/shop/shop_item.tscn")
const ShopStateScript := preload("res://core/shop_state.gd")

signal leave_requested()

@onready var _gold_label: Label   = $Header/Gold
@onready var _hp_label: Label     = $Header/Hp
@onready var _card_list: VBoxContainer  = $Body/Cards/List
@onready var _trait_list: VBoxContainer = $Body/Traits/List
@onready var _heal_host: Control  = $Footer/HealHost
@onready var _toast: Label        = $Toast
@onready var _leave_btn: Button   = $Footer/LeaveBtn

var _run: Resource = null
var _shop: Object = null
var _offers: Dictionary = {}
var _sold: Dictionary = {}  # "card:id" / "trait:id" / "heal:0" → true
var _locale: String = "zh_CN"


func _ready() -> void:
	_shop = ShopStateScript.new()
	_leave_btn.pressed.connect(_on_leave_pressed)


func setup(run_state: Resource, offers: Dictionary, locale: String = "zh_CN") -> void:
	_run = run_state
	_offers = offers
	_locale = locale
	_sold.clear()
	_render()


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

func _render() -> void:
	_gold_label.text = "%s: %d" % [_t("Gold", _locale), int(_run.gold)]
	_hp_label.text = "生命:%d/%d" % [int(_run.player_hp), int(_run.max_hp)]

	_clear(_card_list)
	for c in _offers.get("cards", []):
		var item: Control = ShopItemScene.instantiate()
		_card_list.add_child(item)
		item.bind("card", String(c["id"]), String(c["display"]), int(c["cost"]), _locale)
		item.purchase_requested.connect(_on_purchase)
		if _sold.has("card:" + String(c["id"])):
			item.set_sold_out(true)

	_clear(_trait_list)
	for tr in _offers.get("traits", []):
		var item2: Control = ShopItemScene.instantiate()
		_trait_list.add_child(item2)
		item2.bind("trait", String(tr["id"]), String(tr["display"]), int(tr["cost"]), _locale)
		item2.purchase_requested.connect(_on_purchase)
		if _sold.has("trait:" + String(tr["id"])):
			item2.set_sold_out(true)

	_clear(_heal_host)
	var heal_cost: int = int(_offers.get("heal", {}).get("cost", 50))
	var heal_item: Control = ShopItemScene.instantiate()
	_heal_host.add_child(heal_item)
	heal_item.anchor_right = 1.0
	heal_item.anchor_bottom = 1.0
	heal_item.bind("heal", "heal", _t("Restore 30% Max HP", _locale), heal_cost, _locale)
	heal_item.purchase_requested.connect(_on_purchase)
	if _sold.has("heal:heal"):
		heal_item.set_sold_out(true)


# ---------------------------------------------------------------------------
# Purchase routing
# ---------------------------------------------------------------------------

func _on_purchase(kind: String, id: String) -> void:
	if _run == null:
		return
	var key: String = "%s:%s" % [kind, id]
	if _sold.has(key):
		return

	match kind:
		"card":
			var cost: int = _cost_for(_offers.get("cards", []), id)
			var res: Dictionary = _shop.buy_card(_run.deck, id, cost, int(_run.gold))
			_after_card_or_trait(res, key)
		"trait":
			var cost2: int = _cost_for(_offers.get("traits", []), id)
			# shop_state.buy_trait expects an Array of trait ids — adapt to
			# the run_state's Inventory object by appending the id and let
			# game flow resolve it later. Keep this in sync with whatever
			# main loop wires shop→inventory hand-off.
			var inv_ids: Array = []
			for t in _run.inventory.unsocketed:
				if t != null:
					inv_ids.append(t.id)
			var res2: Dictionary = _shop.buy_trait(inv_ids, id, cost2, int(_run.gold))
			if res2.get("ok", false):
				_run.gold = int(res2["gold_after"])
				_sold[key] = true
				_show_toast(_t("Purchased", _locale))
			else:
				_show_toast(_reason_text(String(res2.get("reason", ""))))
		"heal":
			var res3: Dictionary = _shop.buy_heal(int(_run.player_hp), int(_run.max_hp), int(_run.gold))
			if res3.get("ok", false):
				_run.gold = int(res3["gold_after"])
				_run.player_hp = int(res3["player_hp_after"])
				_sold[key] = true
				_show_toast("+%d HP" % int(res3.get("healed", 0)))
			else:
				_show_toast(_reason_text(String(res3.get("reason", ""))))
	_render()


func _after_card_or_trait(res: Dictionary, key: String) -> void:
	if res.get("ok", false):
		_run.gold = int(res["gold_after"])
		_sold[key] = true
		_show_toast(_t("Purchased", _locale))
	else:
		_show_toast(_reason_text(String(res.get("reason", ""))))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _cost_for(items: Array, id: String) -> int:
	for it in items:
		if String(it.get("id", "")) == id:
			return int(it.get("cost", 0))
	return 0


func _clear(node: Node) -> void:
	for c in node.get_children():
		c.queue_free()


func _show_toast(msg: String) -> void:
	_toast.text = msg
	_toast.modulate = Color(1, 1, 1, 1)
	_toast.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_toast, "modulate:a", 0.0, 1.5)
	tw.tween_callback(func(): _toast.visible = false)


func _on_leave_pressed() -> void:
	leave_requested.emit()


func _t(s: String, locale: String) -> String:
	if locale != "zh_CN":
		return s
	match s:
		"Gold":      return "金币"
		"Cards":     return "卡牌"
		"Traits":    return "词条"
		"Restore 30% Max HP": return "恢复 30% 最大生命"
		"Purchased": return "已购买"
		"Leave":     return "离开"
		_: return s


func _reason_text(reason: String) -> String:
	match reason:
		"insufficient_gold": return "金币不足"
		"inventory_full":    return "词条栏已满"
		"already_full_hp":   return "生命已满"
		_:                   return "操作失败 (%s)" % reason
