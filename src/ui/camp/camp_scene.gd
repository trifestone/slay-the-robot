## ISSUE-013b — CampScene: top-level container that wires DeckPanel +
## InventoryGrid + CampState transactions, plus the per-hover ReactionPreview
## (ISSUE-014b) and the ReforgeDialog (ISSUE-016b).
##
## Inputs are pushed in via `setup(run_state, locale)`. The scene reads
## run_state.{deck, gold, dismantle_points, inventory, traits_collected,
## rare_items} and rewrites those fields in place after each transaction.
##
## Signals out:
##   leave_requested()    # emitted when player presses the Leave button
##
## Sub-scene contracts (the .gd controllers below define these):
##   DeckPanel.bind(cards, locale) / .refresh()
##   InventoryGrid.bind(inventory, locale) / .refresh()
##   ReactionPreview.show_for(card, slot_idx, candidate_trait_id, locale)
##   ReactionPreview.hide_preview()
##   ReforgeDialog.open(card, locale)
extends Control

const DeckPanelScene        := preload("res://ui/camp/deck_panel.tscn")
const InventoryGridScene    := preload("res://ui/camp/inventory_grid.tscn")
const ReactionPreviewScene  := preload("res://ui/camp/reaction_preview.tscn")
const ReforgeDialogScene    := preload("res://ui/camp/reforge_dialog.tscn")

const CampStateScript := preload("res://core/camp_state.gd")
const ReforgeScript   := preload("res://core/reforge.gd")
const ReactionPredictorScript := preload("res://core/reaction_predictor.gd")

signal leave_requested()

@onready var _deck_host: Control      = $Layout/DeckHost
@onready var _inventory_host: Control = $Layout/Sidebar/InventoryHost
@onready var _gold_label: Label       = $Layout/Sidebar/Stats/Gold
@onready var _dismantle_label: Label  = $Layout/Sidebar/Stats/Dismantle
@onready var _toast: Label            = $Toast
@onready var _leave_btn: Button       = $Layout/Sidebar/LeaveBtn

var _run: Resource = null
var _locale: String = "zh_CN"
var _camp: Object = null
var _reforge: Object = null
var _predictor: Object = null

var _deck_panel: Control = null
var _inventory_grid: Control = null
var _reaction_preview: Control = null
var _reforge_dialog: Control = null

# Track which trait id (if any) is currently being dragged so reaction preview
# can show diff on hover before the drop happens.
var _dragging_trait_id: String = ""


func _ready() -> void:
	_camp = CampStateScript.new()
	_reforge = ReforgeScript.new()
	_predictor = ReactionPredictorScript.new()

	_deck_panel = DeckPanelScene.instantiate()
	_deck_host.add_child(_deck_panel)
	_deck_panel.anchor_right = 1.0
	_deck_panel.anchor_bottom = 1.0

	_inventory_grid = InventoryGridScene.instantiate()
	_inventory_host.add_child(_inventory_grid)
	_inventory_grid.anchor_right = 1.0
	_inventory_grid.anchor_bottom = 1.0

	_reaction_preview = ReactionPreviewScene.instantiate()
	add_child(_reaction_preview)
	_reaction_preview.visible = false

	_reforge_dialog = ReforgeDialogScene.instantiate()
	add_child(_reforge_dialog)
	_reforge_dialog.visible = false

	_deck_panel.mount_requested.connect(_on_mount_requested)
	_deck_panel.dismantle_requested.connect(_on_dismantle_requested)
	_deck_panel.reforge_requested.connect(_on_reforge_requested)
	_deck_panel.slot_hovered.connect(_on_slot_hovered)
	_deck_panel.slot_unhovered.connect(_on_slot_unhovered)

	_inventory_grid.trait_drag_started.connect(_on_trait_drag_started)
	_inventory_grid.trait_drag_ended.connect(_on_trait_drag_ended)

	_reforge_dialog.confirm_requested.connect(_on_reforge_confirmed)
	_reforge_dialog.cancel_requested.connect(_on_reforge_cancelled)

	_leave_btn.pressed.connect(_on_leave_pressed)


func setup(run_state: Resource, locale: String = "zh_CN") -> void:
	_run = run_state
	_locale = locale
	if _deck_panel == null:
		# Defer until _ready completed.
		call_deferred("setup", run_state, locale)
		return
	_refresh_all()


# ---------------------------------------------------------------------------
# Mount / dismantle
# ---------------------------------------------------------------------------

func _on_mount_requested(card: Resource, slot_idx: int, trait_id: String) -> void:
	if _run == null:
		return
	var t: Resource = _run.inventory.find_trait_by_id(trait_id) if _run.inventory.has_method("find_trait_by_id") else _find_trait_by_id(trait_id)
	if t == null:
		_show_toast("找不到该词条")
		return
	var res: Dictionary = _camp.mount_trait_to_slot(
		card, slot_idx, t,
		int(_run.gold), int(_run.dismantle_points), _run.inventory)
	_apply_result(res)
	if not res.get("ok", false):
		_show_toast(_reason_text(String(res.get("reason", ""))))
	_refresh_all()


func _on_dismantle_requested(card: Resource, slot_idx: int) -> void:
	if _run == null:
		return
	var res: Dictionary = _camp.dismantle_slot(
		card, slot_idx,
		int(_run.gold), int(_run.dismantle_points), _run.inventory)
	_apply_result(res)
	if not res.get("ok", false):
		_show_toast(_reason_text(String(res.get("reason", ""))))
	_refresh_all()


# ---------------------------------------------------------------------------
# Reforge
# ---------------------------------------------------------------------------

func _on_reforge_requested(card: Resource) -> void:
	if _run == null or card == null:
		return
	if bool(card.reforged):
		_show_toast("该卡已重铸")
		return
	_reforge_dialog.open(card, _locale)


func _on_reforge_confirmed(card: Resource, new_base: String, signature_trait: Resource) -> void:
	var rare: int = int(_run.get("rare_items")) if _run.has_method("get") else 0
	var res: Dictionary = _reforge.reforge(card, new_base, signature_trait, int(_run.gold), rare)
	if res.get("ok", false):
		_run.gold = int(res["gold_after"])
		_run.set("rare_items", int(res["rare_items_after"]))
	else:
		_show_toast(_reason_text(String(res.get("reason", ""))))
	_reforge_dialog.visible = false
	_refresh_all()


func _on_reforge_cancelled() -> void:
	_reforge_dialog.visible = false


# ---------------------------------------------------------------------------
# Reaction preview (ISSUE-014b)
# ---------------------------------------------------------------------------

func _on_slot_hovered(card: Resource, slot_idx: int, _candidate_unused: String) -> void:
	if _dragging_trait_id.is_empty() or card == null or slot_idx == 0:
		return
	_reaction_preview.show_for(card, slot_idx, _dragging_trait_id, _locale, _predictor)


func _on_slot_unhovered(_card: Resource, _slot_idx: int) -> void:
	_reaction_preview.hide_preview()


func _on_trait_drag_started(trait_id: String) -> void:
	_dragging_trait_id = trait_id


func _on_trait_drag_ended() -> void:
	_dragging_trait_id = ""
	_reaction_preview.hide_preview()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _apply_result(res: Dictionary) -> void:
	if not res.get("ok", false):
		return
	_run.gold = int(res.get("gold_after", _run.gold))
	if res.has("dismantle_after"):
		_run.dismantle_points = int(res["dismantle_after"])


func _refresh_all() -> void:
	if _run == null:
		return
	_gold_label.text = "金币:%d" % int(_run.gold)
	_dismantle_label.text = "拆解点:%d" % int(_run.dismantle_points)
	_deck_panel.bind(_run.deck, _locale)
	_inventory_grid.bind(_run.inventory, _locale)


func _find_trait_by_id(trait_id: String) -> Resource:
	if _run == null or _run.inventory == null:
		return null
	for t in _run.inventory.unsocketed:
		if t != null and t.id == trait_id:
			return t
	return null


func _show_toast(msg: String) -> void:
	_toast.text = msg
	_toast.modulate = Color(1, 1, 1, 1)
	_toast.visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_toast, "modulate:a", 0.0, 1.5)
	tw.tween_callback(func(): _toast.visible = false)


func _reason_text(reason: String) -> String:
	match reason:
		"slot_locked":               return "底槽位已锁定"
		"duplicate_trait":           return "已存在相同词条"
		"insufficient_gold":         return "金币不足"
		"insufficient_dismantle_points": return "拆解点不足"
		"inventory_full":            return "词条栏已满"
		"trait_not_removable":       return "该词条不可拆解"
		"trait_not_in_inventory":    return "词条不在库存中"
		"already_reforged":          return "该卡已重铸"
		"insufficient_rare_items":   return "稀有材料不足"
		_:                           return "操作失败 (%s)" % reason


func _on_leave_pressed() -> void:
	leave_requested.emit()
