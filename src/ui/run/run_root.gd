## RunRoot — top-level scheduler that wires the scaffolded scenes
## (Map / Camp / Shop / Battle placeholder / Event placeholder / End screens)
## into a single playable run loop.
##
## Architecture:
##   Single Control root with a `Stage` child. Active scene is instanced into
##   Stage; switching scenes frees the previous one. RunState lives here as
##   a RunStateRes Resource so child scenes can use property access (_run.gold);
##   when battle/run logic needs the Dictionary form (core/run.gd), we round-trip
##   via to_dict()/from_dict().
##
## Flow:
##   _ready -> start_new_run() -> _show_map()
##   on map.node_selected(id) -> route by node type:
##       Camp   -> _show_camp()
##       Shop   -> _show_shop_with_offers()
##       Normal/Elite/Boss -> _resolve_battle(tier)
##       Event  -> _show_event_placeholder()
##   on camp/shop.leave_requested -> _show_map() (with current_id advanced)
##   on outcome != "ongoing" -> _show_end_screen()
extends Control

const RunScript           := preload("res://core/run.gd")
const MapGenScript        := preload("res://core/map_generator.gd")
const RunStateResScript   := preload("res://ui/run/run_state_res.gd")
const MetaStateScript     := preload("res://meta/meta_state.gd")
const TraitScript         := preload("res://data/trait.gd")
const SlotScript          := preload("res://data/slot.gd")
const CardScript          := preload("res://data/card.gd")

const MapSceneScene       := preload("res://ui/map/map_scene.tscn")
const CampSceneScene      := preload("res://ui/camp/camp_scene.tscn")
const ShopSceneScene      := preload("res://ui/shop/shop_scene.tscn")
const BattleSceneScene    := preload("res://ui/battle/battle_scene.tscn")
const DeathScreenScene    := preload("res://ui/end/death_screen.tscn")
const WinScreenScene      := preload("res://ui/end/win_screen.tscn")

const STARTING_HP: int = 80
const META_PATH: String = "user://meta.json"

@onready var _stage: Control = $Stage
@onready var _hud_label: Label = $HUD/RunInfo
@onready var _toast: Label = $HUD/Toast

var _run: Object = null              # core/run.gd instance
var _run_state: Resource = null      # RunStateRes wrapper
var _map: Dictionary = {}
var _current_node_id: String = ""
var _battle_idx: int = 0             # global battle counter (0..17 cap, but map can drive different counts)
var _locale: String = "zh_CN"
var _current_stage: Node = null
var _last_tier: String = "normal"
var _last_node_label: String = "Normal"


func _ready() -> void:
	start_new_run(int(Time.get_unix_time_from_system()))


func start_new_run(seed: int) -> void:
	_run = RunScript.new()
	var dict_state: Dictionary = _run.start_run(seed, _starting_deck(), STARTING_HP)
	_run_state = RunStateResScript.from_dict(dict_state)
	_map = MapGenScript.new().generate(seed)
	_battle_idx = 0
	_current_node_id = ""
	_run_state.visited = []
	_show_map()


# ---------------------------------------------------------------------------
# Stage swap
# ---------------------------------------------------------------------------

func _swap_stage(new_stage: Node) -> void:
	if _current_stage != null and is_instance_valid(_current_stage):
		_current_stage.queue_free()
	_current_stage = new_stage
	_stage.add_child(new_stage)
	if new_stage is Control:
		new_stage.anchor_right = 1.0
		new_stage.anchor_bottom = 1.0
		new_stage.offset_right = 0
		new_stage.offset_bottom = 0
	_refresh_hud()


# ---------------------------------------------------------------------------
# Map
# ---------------------------------------------------------------------------

func _show_map() -> void:
	var map_ui: Control = MapSceneScene.instantiate()
	_swap_stage(map_ui)
	# Defer setup to next frame so @onready vars in map_scene resolve.
	map_ui.node_selected.connect(_on_map_node_selected)
	map_ui.call_deferred("setup", _map, _current_node_id, _run_state.visited, _locale)


func _on_map_node_selected(id: String) -> void:
	var cell: Dictionary = _find_cell(id)
	if cell.is_empty():
		return
	_current_node_id = id
	_run_state.current_node_id = id
	if not _run_state.visited.has(id):
		_run_state.visited.append(id)

	var node_type: String = String(cell.get("type", "Normal"))
	match node_type:
		"Camp":   _show_camp()
		"Shop":   _show_shop()
		"Normal": _resolve_battle("normal", node_type)
		"Elite":  _resolve_battle("elite", node_type)
		"Boss":   _resolve_battle("boss", node_type)
		"Event":  _show_event_placeholder()
		_:        _show_event_placeholder()


# ---------------------------------------------------------------------------
# Camp / Shop
# ---------------------------------------------------------------------------

func _show_camp() -> void:
	var camp: Control = CampSceneScene.instantiate()
	_swap_stage(camp)
	camp.leave_requested.connect(_on_subscene_leave)
	camp.call_deferred("setup", _run_state, _locale)


func _show_shop() -> void:
	var shop: Control = ShopSceneScene.instantiate()
	_swap_stage(shop)
	shop.leave_requested.connect(_on_subscene_leave)
	shop.call_deferred("setup", _run_state, _make_default_offers(), _locale)


func _on_subscene_leave() -> void:
	_check_outcome_and_continue()


# ---------------------------------------------------------------------------
# Battle (live BattleScene; ISSUE-023)
# ---------------------------------------------------------------------------

func _resolve_battle(tier: String, node_label: String) -> void:
	_last_tier = tier
	_last_node_label = node_label
	var bs: Control = BattleSceneScene.instantiate()
	_swap_stage(bs)
	bs.battle_finished.connect(_on_battle_finished)
	# Defer setup so @onready vars inside BattleScene resolve.
	bs.call_deferred("setup", _run_state, tier, _locale)


func _on_battle_finished(result: Dictionary) -> void:
	var won: bool = bool(result.get("won", false))
	var hp_left: int = int(result.get("hp_left", _run_state.player_hp))
	_run_state.player_hp = hp_left
	if won:
		var gold: int = _gold_for_tier(_last_tier)
		_run_state.gold = int(_run_state.gold) + gold
		_run_state.battles_won = int(_run_state.battles_won) + 1
		_show_toast("击败 %s,生命:%d/%d (+%d 金币)" % [
			_last_node_label, hp_left, int(_run_state.max_hp), gold])
	else:
		_run_state.outcome = "lost"
		_show_toast("被 %s 击败,生命归零" % _last_node_label)
	_battle_idx += 1
	_refresh_hud()
	_check_outcome_and_continue()


func _gold_for_tier(tier: String) -> int:
	match tier:
		"normal": return 5
		"elite":  return 15
		"boss":   return 30
	return 0


# ---------------------------------------------------------------------------
# Event placeholder (until ISSUE-event-system is built)
# ---------------------------------------------------------------------------

func _show_event_placeholder() -> void:
	_show_toast("事件节点暂未实现 — 已跳过")
	_check_outcome_and_continue()


# ---------------------------------------------------------------------------
# Outcome / End screens
# ---------------------------------------------------------------------------

func _check_outcome_and_continue() -> void:
	var outcome: String = String(_run_state.outcome)
	if outcome == "lost":
		_show_end_screen(false)
		return
	# Boss kill at the end of act 2 = run win.
	if _battle_idx >= 18 and outcome == "ongoing":
		_run_state.outcome = "won"
		_show_end_screen(true)
		return
	_show_map()


func _show_end_screen(won: bool) -> void:
	var meta: Dictionary = _load_meta()
	var summary: Dictionary = {
		"won":                  won,
		"first_battle_death":   _battle_idx <= 1 and not won,
		"traits_collected":     _run_state.traits_collected.duplicate(),
		"trait_element_map":    {},  # filled when ISSUE-014 trait taxonomy lands
	}
	var meta_delta: Dictionary = MetaStateScript.new().apply_run_result(meta, summary)
	_save_meta(meta)

	var screen: Control
	if won:
		screen = WinScreenScene.instantiate()
	else:
		screen = DeathScreenScene.instantiate()
	_swap_stage(screen)
	screen.return_requested.connect(_on_return_to_menu)
	screen.call_deferred("show_for", _run_state, meta_delta, _locale)


func _on_return_to_menu() -> void:
	# For now "return to menu" = start a fresh run. A real menu scene can
	# be wired in later (ISSUE-meta-menu).
	start_new_run(int(Time.get_unix_time_from_system()))


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Build starting deck guaranteeing at least one Block card.
func _starting_deck() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(Time.get_unix_time_from_system())
	var pool: Array = _starter_trait_pool()
	var deck: Array = []
	var has_block: bool = false
	for i in range(5):
		var slot_count: int = rng.randi_range(1, 3)
		var traits: Array = []
		for j in range(slot_count):
			traits.append(pool[rng.randi_range(0, pool.size() - 1)])
		var card = _make_starter_card_from_traits(traits)
		deck.append(card)
		# Check if this card has any Block trait
		for slot in card.slots:
			if slot != null and slot.trait_ref != null:
				if slot.trait_ref.effect_type == "Block":
					has_block = true
					break
	# Guarantee at least one block card
	if not has_block:
		var guard_traits: Array = [_mk_trait("guard", 0, "Block", 5, "防御")]
		deck[0] = _make_starter_card_from_traits(guard_traits)
	return deck


## Six hand-picked traits that play nicely together for a first run.
## Added extra Block traits and guarantee at least one Block card in deck.
func _starter_trait_pool() -> Array:
	var pool: Array = []
	pool.append(_mk_trait("slash",  0, "Damage", 6,  "斩击"))
	pool.append(_mk_trait("guard",  0, "Block",  5,  "防御"))
	pool.append(_mk_trait("burn",   0, "Damage", 4,  "灼烧"))
	pool.append(_mk_trait("focus",  0, "Draw",   1,  "凝神"))
	pool.append(_mk_trait("leech",  0, "Heal",   2,  "汲取"))
	pool.append(_mk_trait("ember",  0, "Damage", 3,  "余烬"))
	# Extra block traits for better variety
	pool.append(_mk_trait("shield", 0, "Block",  4,  "护盾"))
	pool.append(_mk_trait("barrier",0, "Block",  6,  "屏障"))
	return pool


func _mk_trait(id: String, trigger: int, effect_type: String,
		effect_value: int, flavor: String) -> Resource:
	var t: Resource = TraitScript.new()
	t.id                = id
	t.trigger           = trigger
	t.effect_type       = effect_type
	t.effect_value      = effect_value
	t.axis_timing       = trigger
	t.axis_scope        = 0
	t.axis_school       = 0
	t.rarity            = 0
	t.cooldown_per_turn = -1
	t.removable         = true
	t.flavor            = flavor
	return t


func _make_starter_card_from_traits(traits: Array) -> Resource:
	# First slot is locked (the card's "base"). Remaining slots filled with
	# any leftover traits or empty.
	var slots: Array = []
	for i in range(3):
		var s: Resource = SlotScript.new()
		s.index     = i
		s.trait_ref = traits[i] if i < traits.size() else null
		s.locked    = (i == 0)
		s.post_load()
		slots.append(s)
	var card: Resource = CardScript.new()
	card.slots = slots
	return card


func _make_default_offers() -> Dictionary:
	# Minimal placeholder. Real offer generation happens in a (future)
	# shop_offer_generator hooked into RNG + run_state.
	return {
		"cards":  [],
		"traits": [],
		"heal":   {"cost": 50},
	}


func _find_cell(id: String) -> Dictionary:
	for act in _map.get("acts", []):
		for row in act.get("floors", []):
			for cell in row:
				if cell == null:
					continue
				if String(cell.get("id", "")) == id:
					return cell
	return {}


func _load_meta() -> Dictionary:
	var ms: Object = MetaStateScript.new()
	if not FileAccess.file_exists(META_PATH):
		return ms.make_default()
	var f: FileAccess = FileAccess.open(META_PATH, FileAccess.READ)
	if f == null:
		return ms.make_default()
	var text: String = f.get_as_text()
	f.close()
	return ms.from_json(text)


func _save_meta(meta: Dictionary) -> void:
	var f: FileAccess = FileAccess.open(META_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(MetaStateScript.new().to_json(meta))
	f.close()


func _refresh_hud() -> void:
	if _run_state == null:
		return
	_hud_label.text = "生命 %d/%d  |  金币 %d  |  战斗 %d/18  |  节点 %s" % [
		int(_run_state.player_hp), int(_run_state.max_hp),
		int(_run_state.gold), _battle_idx, _current_node_id]


func _show_toast(msg: String) -> void:
	_toast.text = msg
	_toast.modulate = Color(1, 1, 1, 1)
	_toast.visible = true
	var tw: Tween = create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(_toast, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func(): _toast.visible = false)
