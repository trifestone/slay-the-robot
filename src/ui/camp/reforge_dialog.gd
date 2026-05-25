## ISSUE-016b — Reforge confirmation dialog.
##
## Modal that opens when the player clicks "Reforge" on a CardCampUI.
## Player picks a target base from the available list; the dialog looks up
## the corresponding signature trait via the injected `base_signatures` map
## and emits `confirm_requested(card, new_base, signature_trait)` so
## camp_scene can call core/reforge.gd.
##
## Public API:
##   open(card, locale)                  # show modal for this card
##   set_base_signatures(map)            # {"Attack": Trait, "Rite": Trait, ...}
##   set_costs(gold, rare_items)         # display the cost line
##
## Signals:
##   confirm_requested(card, new_base, signature_trait)
##   cancel_requested()
extends Control

const REFORGE_GOLD_COST: int      = 100
const REFORGE_RARE_ITEM_COST: int = 1

signal confirm_requested(card: Resource, new_base: String, signature_trait: Resource)
signal cancel_requested()

@onready var _veil: ColorRect       = $Veil
@onready var _panel: Panel          = $Panel
@onready var _title: Label          = $Panel/V/Title
@onready var _body: Label           = $Panel/V/Body
@onready var _base_dropdown: OptionButton = $Panel/V/BaseDropdown
@onready var _cost_label: Label     = $Panel/V/Cost
@onready var _confirm_btn: Button   = $Panel/V/Buttons/Confirm
@onready var _cancel_btn: Button    = $Panel/V/Buttons/Cancel

var _card: Resource = null
var _locale: String = "zh_CN"
# {"Attack": Trait, "Rite": Trait, ...}
var _base_signatures: Dictionary = {}


func _ready() -> void:
	visible = false
	_veil.color = Color(0, 0, 0, 0.55)
	_confirm_btn.pressed.connect(_on_confirm_pressed)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_veil.gui_input.connect(_on_veil_input)


func set_base_signatures(map: Dictionary) -> void:
	_base_signatures = map


func open(card: Resource, locale: String = "zh_CN") -> void:
	_card = card
	_locale = locale
	_render()
	visible = true


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

func _render() -> void:
	if _card == null:
		return
	_title.text = _t("Reforge", _locale)
	_body.text = _t("Choose a new base. Slots 1 and 2 are preserved.", _locale)

	_base_dropdown.clear()
	var current: String = String(_card.base)
	var idx: int = 0
	var keys: Array = _base_signatures.keys()
	keys.sort()
	for k in keys:
		if String(k) == current:
			continue  # cannot reforge into the same base
		_base_dropdown.add_item(String(k), idx)
		idx += 1

	if _base_dropdown.item_count == 0:
		# Fallback when no signatures injected yet — show a single placeholder
		# so the dialog renders, but block confirm.
		_base_dropdown.add_item(_t("(no targets)", _locale), 0)
		_confirm_btn.disabled = true
	else:
		_confirm_btn.disabled = false
		_base_dropdown.selected = 0

	_cost_label.text = "%s: %d %s + %d %s" % [
		_t("Cost", _locale),
		REFORGE_GOLD_COST, _t("gold", _locale),
		REFORGE_RARE_ITEM_COST, _t("rare item", _locale),
	]


# ---------------------------------------------------------------------------
# Buttons
# ---------------------------------------------------------------------------

func _on_confirm_pressed() -> void:
	if _card == null or _base_dropdown.item_count == 0:
		return
	var new_base: String = _base_dropdown.get_item_text(_base_dropdown.selected)
	if new_base.is_empty():
		return
	var sig: Resource = _base_signatures.get(new_base, null)
	if sig == null:
		return  # injection incomplete; UI prevents progress
	confirm_requested.emit(_card, new_base, sig)


func _on_cancel_pressed() -> void:
	cancel_requested.emit()


func _on_veil_input(event: InputEvent) -> void:
	# Click outside panel = cancel.
	if event is InputEventMouseButton and event.pressed:
		cancel_requested.emit()


# ---------------------------------------------------------------------------
# i18n placeholder
# ---------------------------------------------------------------------------

func _t(s: String, locale: String) -> String:
	if locale != "zh_CN":
		return s
	match s:
		"Reforge":     return "重铸"
		"Choose a new base. Slots 1 and 2 are preserved.": return "选择新的基底,槽位 1/2 将被保留。"
		"Cost":        return "代价"
		"gold":        return "金币"
		"rare item":   return "稀有物品"
		"(no targets)": return "(暂无可选基底)"
		"Confirm":     return "确认"
		"Cancel":      return "取消"
		_: return s
