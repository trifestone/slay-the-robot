## ISSUE-023 — BattleScene: composes HandUI / EnemyUI / HoverPreviewView /
## VFXLayer / EndTurnButton + EnergyLabel into a playable battle, driven by
## core/battle_loop.gd. Emits `battle_finished({won, hp_left, drops})` when
## is_over() flips, so run_root can return to the map.
##
## Public API:
##   setup(run_state: Resource, tier: String, locale: String) -> void
##
## All emit() calls go through AnimSignaler so VFXLayer gets uniform
## notifications (no direct EmitScript.emit() in this scene).
extends Control

const BattleLoopScript    := preload("res://core/battle_loop.gd")
const AnimSignalerScript  := preload("res://core/anim_signaler.gd")
const EnemyFactoryScript  := preload("res://core/enemy_factory.gd")
const DropTableScript     := preload("res://core/drop_table.gd")
const HoverPreviewLogic   := preload("res://ui/hover_preview.gd")

signal battle_finished(result: Dictionary)

@onready var _enemy_row: HBoxContainer = $EnemyRow
@onready var _hand_ui:  Control      = $HandUI
@onready var _hover_view: Control    = $HoverPreview
@onready var _vfx_layer: Control     = $VFXLayer
@onready var _end_btn:  Button       = $EndTurnButton
@onready var _energy_lbl: Label      = $EnergyLabel
@onready var _hp_lbl:   Label        = $PlayerHpLabel
@onready var _player_ui: Control     = $PlayerUI

const EnemyUIScene := preload("res://ui/enemy_ui.tscn")

var _enemy_widgets: Array = []  # Array[EnemyUI Control], one per state.enemies entry

var _run_state: Resource = null
var _tier: String = "normal"
var _locale: String = "zh_CN"

var _loop: Object = null
var _state: Object = null
var _signaler: Node = null
var _hover_resolver: Object = null
var _finished: bool = false

## Target-selection state (multi-enemy fights).
## When the player clicks a Damage card with 2+ alive enemies, we arm the
## card and wait for an EnemyUI click before resolving play_card.
var _armed_card: Resource = null
var _armed_hint: Label = null

## End-turn summary accumulators (reset per turn).
var _turn_dmg_dealt: int = 0
var _turn_dmg_taken: int = 0
var _turn_kills: int = 0
var _summary_panel: Control = null

## Hold the summary on screen for this many seconds before run_root flips
## back to the map. Tests set it to 0 so the regression suite stays fast.
var _finalize_delay_seconds: float = 2.6

const DAMAGE_TIPS_ZH := "请点击目标敌人"
const DAMAGE_TIPS_CANCEL_ZH := " (右键 / Esc 取消)"

const HAND_HEIGHT: float = 360.0  # Match HandUI.HAND_HEIGHT


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

func setup(run_state: Resource, tier: String = "normal", locale: String = "zh_CN") -> void:
	_run_state = run_state
	_tier = tier
	_locale = locale

	_loop = BattleLoopScript.new()
	_signaler = AnimSignalerScript.new()
	add_child(_signaler)
	_hover_resolver = HoverPreviewLogic.new()

	# Resolve enemy group from tier. EnemyFactory.build_group returns an
	# Array of entries (1 for normal, 2 for elite, 3 for boss). BattleLoop
	# accepts the array directly and populates state.enemies.
	var ef: Object = EnemyFactoryScript.new()
	var group: Array = ef.build_group(tier)

	# Start battle. start_battle(enemy=Array) populates state.enemies.
	var seed: int = _battle_seed()
	_state = _loop.start_battle(
		int(_run_state.player_hp),
		int(_run_state.max_hp),
		_run_state.deck.duplicate(),
		group,
		seed
	)

	# Spawn one EnemyUI widget per entry into EnemyRow.
	_rebuild_enemy_widgets()

	# Re-wire the public emit channel inside the loop to go through signaler.
	# battle_loop.gd already uses its own emitter directly, so we wrap the
	# public callers (play_card / start of turn) here at the UI layer:
	#   - we mirror the trait_fire_log diff into AnimSignaler manually after
	#     each play_card / end_turn call. See _emit_signals_for_new_log_entries.

	# Wire VFX layer to all enemy widgets so per-target lunge/shake routes
	# correctly. The primary widget remains the default fallback for legacy
	# single-target VFX (reaction_burst, devour_kill).
	_vfx_layer.bind(_signaler, _enemy_widgets, _player_ui)
	_vfx_layer.drops_announced.connect(_on_drops_announced)
	# Aim the player's lunge toward the enemy row (works for both LTR and
	# unusual layouts where enemies might land left of the player).
	if _vfx_layer.has_method("set_player_lunge_dir_from"):
		var anchor: Control = _primary_enemy_widget()
		if anchor != null:
			_vfx_layer.set_player_lunge_dir_from(_player_ui, anchor)

	# Initial render (without hand — cards will be dealt with animation).
	_refresh_without_hand()

	# Deal cards with animation (optimization 2).
	# Deck position: off-screen left, centered vertically near hand area.
	var deck_pos: Vector2 = Vector2(-300, size.y - HAND_HEIGHT * 0.5)
	_hand_ui.animate_deal(_state.hand, _locale, deck_pos, _on_deal_complete)

	# Hook end turn button (hand signals hooked after deal animation).
	_end_btn.pressed.connect(_on_end_turn_pressed)


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

func _refresh_all() -> void:
	_hand_ui.bind(_state, _locale)
	_hook_hand_card_signals()
	_refresh_enemy_widgets()
	_energy_lbl.text = "能量:%d / %d" % [_state.energy, _state.max_energy]
	_hp_lbl.text = "生命:%d / %d" % [_state.player_hp, _state.max_hp]
	var block: int = int(_state.player_block) if "player_block" in _state else 0
	_player_ui.bind(_state.player_hp, _state.max_hp, block)
	_end_btn.text = "结束回合"
	_end_btn.disabled = _finished
	# Refresh the VFXLayer's widget list so newly-spawned enemy widgets get
	# the proper lunge/shake target after a rebuild.
	if _vfx_layer != null and _vfx_layer.has_method("update_enemy_widgets"):
		_vfx_layer.update_enemy_widgets(_enemy_widgets)
	_update_armed_hint()


## Refresh everything except the hand (used during initial deal animation).
func _refresh_without_hand() -> void:
	_refresh_enemy_widgets()
	_energy_lbl.text = "能量:%d / %d" % [_state.energy, _state.max_energy]
	_hp_lbl.text = "生命:%d / %d" % [_state.player_hp, _state.max_hp]
	var block: int = int(_state.player_block) if "player_block" in _state else 0
	_player_ui.bind(_state.player_hp, _state.max_hp, block)
	_end_btn.text = "结束回合"
	_end_btn.disabled = true  # Disabled during deal animation
	if _vfx_layer != null and _vfx_layer.has_method("update_enemy_widgets"):
		_vfx_layer.update_enemy_widgets(_enemy_widgets)


## Called after card dealing animation completes.
func _on_deal_complete() -> void:
	_hook_hand_card_signals()
	if not _finished:
		_end_btn.disabled = false


func _hook_hand_card_signals() -> void:
	# HandUI re-renders its row every bind(); reconnect listeners each time.
	var row: Node = _hand_ui.get_node("Row")
	for child in row.get_children():
		if not child.card_clicked.is_connected(_on_card_clicked):
			child.card_clicked.connect(_on_card_clicked)
		# Bind the source CardUI so the hover handler can anchor the
		# preview tooltip above the actual card the cursor is on.
		if not child.card_hovered.is_connected(_on_card_hovered):
			child.card_hovered.connect(_on_card_hovered.bind(child))
		if not child.card_unhovered.is_connected(_on_card_unhovered):
			child.card_unhovered.connect(_on_card_unhovered)


## Show a floating "能量不足" hint centered on screen when energy is insufficient.
func _show_energy_hint(text: String) -> void:
	var hint: Label = Label.new()
	hint.text = text
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_color_override("font_color", Color(1, 0.85, 0.3, 1))
	hint.add_theme_font_size_override("font_size", 28)
	add_child(hint)
	# Center on screen (battle scene size).
	var label_size: Vector2 = Vector2(200, 40)
	hint.size = label_size
	hint.position = Vector2(size.x * 0.5 - label_size.x * 0.5, size.y * 0.35)
	hint.modulate.a = 0.0
	# Animate: fade in -> hold -> fade out + float up.
	var tw: Tween = create_tween()
	tw.tween_property(hint, "modulate:a", 1.0, 0.15)
	tw.tween_interval(0.6)  # Hold for readability
	tw.chain().tween_property(hint, "position", hint.position + Vector2(0, -30), 0.4)
	tw.parallel().tween_property(hint, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(hint.queue_free)


# ---------------------------------------------------------------------------
# Input handlers
# ---------------------------------------------------------------------------

func _on_card_clicked(card: Resource) -> void:
	if _finished or card == null:
		return
	if _state.energy < 1:
		_flash_energy_insufficient()
		return
	if not _state.hand.has(card):
		return
	# Multi-enemy + Damage card: arm the card and prompt for a target.
	if _needs_target_selection(card):
		_arm_card(card)
		return
	_resolve_play_card(card, null)


## Flash the energy label red and show "能量不足" hint when player tries to play with insufficient energy.
func _flash_energy_insufficient() -> void:
	var original_color: Color = _energy_lbl.modulate
	var flash_color: Color = Color(1, 0.2, 0.2, 1)  # Bright red

	# Create flash tween: white -> red -> white (3 pulses for "叮叮叮" feel)
	var tw: Tween = create_tween()
	tw.tween_property(_energy_lbl, "modulate", flash_color, 0.08)
	tw.tween_property(_energy_lbl, "modulate", original_color, 0.08)
	tw.tween_property(_energy_lbl, "modulate", flash_color, 0.08)
	tw.tween_property(_energy_lbl, "modulate", original_color, 0.08)
	tw.tween_property(_energy_lbl, "modulate", flash_color, 0.08)
	tw.tween_property(_energy_lbl, "modulate", original_color, 0.12)

	# Show floating hint "能量不足"
	_show_energy_hint("能量不足")


func _resolve_play_card(card: Resource, target) -> void:
	var log_before: int = _state.trait_fire_log.size()
	var dmg_before: int = _damage_events_size()
	var enemies_alive_before: int = _alive_enemy_count()
	var hp_before: int = int(_state.player_hp)
	var block_before: int = int(_state.player_block) if "player_block" in _state else 0
	_loop.play_card(_state, card, target)
	_emit_signals_for_new_log_entries(log_before, card)
	_emit_strike_signals(dmg_before, target)
	# Detect heal and block changes for VFX.
	_detect_hp_and_block_changes(hp_before, block_before)
	# Accumulate damage dealt this turn (sum dmg from new damage_events).
	_turn_dmg_dealt += _damage_events_sum_since(dmg_before)
	# Count newly-killed enemies (alive count drop).
	var enemies_alive_after: int = _alive_enemy_count()
	if enemies_alive_after < enemies_alive_before:
		_turn_kills += enemies_alive_before - enemies_alive_after
	_clear_armed_card()
	# When this play wins the fight, show the per-turn summary first so the
	# player can read their stats before run_root swaps back to the map.
	var result: Dictionary = _loop.is_over(_state)
	if not result.get("ongoing", true):
		if not _finished:
			_finished = true
			_end_btn.disabled = true
			# Prepare drops and trigger win VFX before showing summary.
			if result.get("won", false):
				var drops: Array = _roll_drops()
				var killed: Resource = _last_killed_enemy()
				if killed == null:
					killed = _state.enemy
				_signaler.notify_enemy_killed(killed, drops)
				_run_state.player_hp = int(_state.player_hp)
				set_meta("_battle_result", {"won": true, "drops": drops})
			else:
				set_meta("_battle_result", {"won": false, "drops": []})
			_show_end_turn_summary(int(_state.player_hp), true)
			_reset_turn_stats()
		return
	if not _finished:
		_refresh_all()


func _on_end_turn_pressed() -> void:
	if _finished:
		return
	_clear_armed_card()
	var log_before: int = _state.trait_fire_log.size()
	var hp_before: int = int(_state.player_hp)
	var block_before: int = int(_state.player_block) if "player_block" in _state else 0
	var dmg_before: int = _damage_events_size()
	_loop.end_turn(_state)
	# Emit enemy lunge signals for alive enemies that have intent damage.
	if _state.enemies != null:
		for i in range(_state.enemies.size()):
			var entry: Dictionary = _state.enemies[i]
			if int(entry.get("hp", 0)) > 0 and int(entry.get("intent_damage", 0)) > 0:
				_signaler.notify_enemy_lunged(i)
	# Cards in hand at start of new turn — pass null so signaler keys are stable.
	_emit_signals_for_new_log_entries(log_before, null)
	_emit_strike_signals(dmg_before, null)
	var hp_after: int = int(_state.player_hp)
	if hp_after < hp_before:
		_signaler.notify_enemy_attacked(hp_before - hp_after)
		_turn_dmg_taken += hp_before - hp_after
	# Block was consumed during enemy attack — emit delta now that we know it.
	var block_after: int = int(_state.player_block) if "player_block" in _state else 0
	if block_after != block_before:
		_signaler.notify_block_changed(block_after - block_before, false, block_after)
	# Check if battle ended — determines which buttons to show.
	var result: Dictionary = _loop.is_over(_state)
	var is_battle_end: bool = not result.get("ongoing", true)
	if is_battle_end:
		_finished = true
		_end_btn.disabled = true
	# Refresh PlayerUI to show updated HP/block after enemy attack BEFORE showing summary.
	_refresh_player_ui_only()
	# Always show the turn summary (now modal with buttons).
	_show_end_turn_summary(hp_after, is_battle_end)
	if is_battle_end:
		# Store result for the return-to-menu handler.
		set_meta("_battle_result", result)


## Refresh only the player UI (HP bar, block display) without touching hand/enemies.
## Used during end-turn flow to show enemy attack results before the summary panel.
func _refresh_player_ui_only() -> void:
	if _state == null:
		return
	var block: int = int(_state.player_block) if "player_block" in _state else 0
	_player_ui.bind(_state.player_hp, _state.max_hp, block)
	_hp_lbl.text = "生命:%d / %d" % [_state.player_hp, _state.max_hp]


func _on_card_hovered(card: Resource, source: Control = null) -> void:
	if _finished or card == null:
		return
	_hover_view.show_for(card, _state, _hover_anchor_for(source))


func _on_card_unhovered(_card: Resource) -> void:
	_hover_view.hide_preview()


func _unhandled_input(event: InputEvent) -> void:
	if _armed_card == null:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_clear_armed_card()
		_update_armed_hint()
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			_clear_armed_card()
			_update_armed_hint()


# ---------------------------------------------------------------------------
# Target selection (multi-enemy)
# ---------------------------------------------------------------------------

## True when a card should require an explicit target choice.
## Triggered for Damage-effect cards when 2+ enemies are alive.
func _needs_target_selection(card: Resource) -> bool:
	if card == null or _state == null:
		return false
	if _state.enemies == null or _state.enemies.size() < 2:
		return false
	if _alive_enemy_count() < 2:
		return false
	return _card_has_damage(card)


func _alive_enemy_count() -> int:
	var n: int = 0
	if _state == null or _state.enemies == null:
		return 0
	for entry in _state.enemies:
		if int(entry.get("hp", 0)) > 0:
			n += 1
	return n


func _card_has_damage(card: Resource) -> bool:
	if card == null:
		return false
	for slot in card.slots:
		if slot == null:
			continue
		var t: Resource = slot.trait_ref
		if t != null and "effect_type" in t and String(t.effect_type) == "Damage":
			return true
	return false


func _arm_card(card: Resource) -> void:
	_armed_card = card
	_update_armed_hint()


func _clear_armed_card() -> void:
	_armed_card = null


func _update_armed_hint() -> void:
	if _armed_hint == null:
		_armed_hint = Label.new()
		_armed_hint.name = "ArmedHint"
		_armed_hint.add_theme_color_override("font_color", Color(1, 0.85, 0.4, 1))
		_armed_hint.add_theme_font_size_override("font_size", 28)
		_armed_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(_armed_hint)
	if _armed_card == null:
		_armed_hint.visible = false
		return
	_armed_hint.text = DAMAGE_TIPS_ZH + DAMAGE_TIPS_CANCEL_ZH
	# Center on screen like energy hint.
	var label_size: Vector2 = Vector2(400, 40)
	_armed_hint.size = label_size
	_armed_hint.position = Vector2(size.x * 0.5 - label_size.x * 0.5, size.y * 0.35)
	_armed_hint.visible = true
	# Auto-fade after 2 seconds if user doesn't interact.
	if _armed_hint.has_meta("fade_tween"):
		var old_tw: Tween = _armed_hint.get_meta("fade_tween")
		if old_tw != null:
			old_tw.kill()
	var tw: Tween = create_tween()
	_armed_hint.set_meta("fade_tween", tw)
	_armed_hint.modulate.a = 1.0
	tw.tween_interval(2.0)
	tw.chain().tween_property(_armed_hint, "modulate:a", 0.0, 0.4)
	tw.parallel().tween_property(_armed_hint, "position", _armed_hint.position + Vector2(0, -30), 0.4)


func _on_enemy_widget_clicked(idx: int) -> void:
	if _finished:
		return
	if _armed_card == null:
		return
	if _state == null or _state.enemies == null:
		return
	if idx < 0 or idx >= _state.enemies.size():
		return
	if int(_state.enemies[idx].get("hp", 0)) <= 0:
		return
	var card: Resource = _armed_card
	_clear_armed_card()
	_resolve_play_card(card, idx)


func _damage_events_size() -> int:
	if _state == null:
		return 0
	if not ("damage_events" in _state):
		return 0
	return _state.damage_events.size()


## Replay each new damage_events tail entry as attacker_lunged + damage_dealt
## so VFXLayer plays one strike per logical damage hit.
func _emit_strike_signals(before: int, target) -> void:
	if _state == null or not ("damage_events" in _state):
		return
	var events: Array = _state.damage_events
	for i in range(before, events.size()):
		var ev: Dictionary = events[i]
		var idx: int = int(ev.get("idx", -1))
		if idx < 0:
			# Legacy single-enemy path used -1; route to primary.
			idx = int(_state.primary_enemy_idx)
		_signaler.emit_signal("attacker_lunged", idx)
		_signaler.emit_signal(
			"damage_dealt",
			idx,
			int(ev.get("dmg", 0)),
			int(ev.get("blocked", 0)),
		)


# ---------------------------------------------------------------------------
# Outcome
# ---------------------------------------------------------------------------

func _check_and_finish() -> void:
	if _finished:
		return
	var result: Dictionary = _loop.is_over(_state)
	if result.get("ongoing", true):
		return
	_finished = true
	_end_btn.disabled = true
	_finalize_battle_after_summary(result)


## Prepares drops and waits for summary dismissal before emitting battle_finished.
## When the player clicks "返回" on the summary, _on_summary_return_to_menu
## will call this and emit the signal.
func _finalize_battle_after_summary(result: Dictionary) -> void:
	var won: bool = bool(result.get("won", false))
	var drops: Array = []
	if won:
		drops = _roll_drops()
		var killed: Resource = _last_killed_enemy()
		if killed == null:
			killed = _state.enemy
		_signaler.notify_enemy_killed(killed, drops)
	# Sync HP back into run_state.
	_run_state.player_hp = int(_state.player_hp)
	# Emit immediately (button handlers control the flow now).
	battle_finished.emit({
		"won":     won,
		"hp_left": int(_state.player_hp),
		"drops":   drops,
	})


func _last_killed_enemy() -> Resource:
	if _state == null or _state.enemies == null:
		return null
	for entry in _state.enemies:
		if int(entry.get("hp", 0)) <= 0:
			var e: Resource = entry.get("enemy", null)
			if e != null:
				return e
	return null


func _roll_drops() -> Array:
	if _state.enemy == null:
		return []
	var rng: RandomNumberGenerator = _state.rng
	if rng == null:
		rng = RandomNumberGenerator.new()
	var dt: Object = DropTableScript.new()
	var carried: Array = []
	for t in _state.enemy.carried_traits:
		if t == null:
			continue
		if typeof(t) == TYPE_STRING:
			carried.append(t)
		elif "id" in t:
			carried.append(String(t.id))
	if carried.is_empty():
		return []
	return dt.roll_drops(carried, _tier, rng, _run_state.trait_rarity_map)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## After play_card resolves, compare HP and block to emit heal / block VFX signals.
func _detect_hp_and_block_changes(hp_before: int, block_before: int) -> void:
	var hp_after: int = int(_state.player_hp)
	var block_after: int = int(_state.player_block) if "player_block" in _state else 0
	if hp_after > hp_before:
		_signaler.notify_player_healed(hp_after - hp_before)
	if block_after != block_before:
		_signaler.notify_block_changed(block_after - block_before, true, block_after)


func _battle_seed() -> int:
	var s: int = int(_run_state.seed)
	if s == 0:
		s = int(Time.get_unix_time_from_system())
	# Mix the visited-count so each fight in the same run has a different seed.
	return s ^ (int(_run_state.visited.size()) * 0x9E3779B1)


func _enemy_max_hp() -> int:
	# Used when rendering each entry's HP bar fallback (entries already
	# carry max_hp from build_group, so this is only a safety net).
	if _state == null:
		return 25
	if _state.enemies != null and not _state.enemies.is_empty():
		var idx: int = int(_state.primary_enemy_idx)
		return int(_state.enemies[idx].get("max_hp", _state.enemy_hp))
	return _state.enemy_hp


func _intent_damage() -> int:
	if _state == null or _state.enemy == null:
		return 0
	if "intent_damage" in _state.enemy:
		return int(_state.enemy.intent_damage)
	return 5


# ---------------------------------------------------------------------------
# Multi-enemy widgets
# ---------------------------------------------------------------------------

func _rebuild_enemy_widgets() -> void:
	for child in _enemy_row.get_children():
		child.queue_free()
	_enemy_widgets.clear()
	if _state == null or _state.enemies == null:
		return
	for i in range(_state.enemies.size()):
		var ui: Control = EnemyUIScene.instantiate()
		_enemy_row.add_child(ui)
		_enemy_widgets.append(ui)
		# Bind a per-index click handler so target selection knows which enemy was hit.
		if ui.has_signal("enemy_clicked"):
			ui.enemy_clicked.connect(_on_enemy_widget_clicked.bind(i))


func _refresh_enemy_widgets() -> void:
	if _state == null or _state.enemies == null:
		return
	# Re-spawn if the count drifted (e.g. battle restart with a different tier).
	if _enemy_widgets.size() != _state.enemies.size():
		_rebuild_enemy_widgets()
	for i in range(_state.enemies.size()):
		var entry: Dictionary = _state.enemies[i]
		var ui: Control = _enemy_widgets[i]
		if ui == null or not is_instance_valid(ui):
			continue
		var enemy: Resource = entry.get("enemy", null)
		var hp: int = int(entry.get("hp", 0))
		var max_hp: int = int(entry.get("max_hp", hp))
		var intent_str: String = String(entry.get("intent", "Attack"))
		var intent_value: int = _get_intent_value_for_display(entry, enemy)
		ui.bind(enemy, hp, max_hp, intent_str, intent_value, _locale)
		# Dim dead enemies so the player can see the focus shift.
		ui.modulate = Color(0.4, 0.4, 0.4, 0.6) if hp <= 0 else Color(1, 1, 1, 1)


## Get appropriate display value for an enemy's current intent.
func _get_intent_value_for_display(entry: Dictionary, enemy: Resource) -> int:
	var intent: String = String(entry.get("intent", "Attack"))
	match intent:
		"Block":
			var block_val: int = entry.get("intent_block", 0)
			if block_val > 0:
				return block_val
			if enemy != null and "intent_block" in enemy:
				return enemy.intent_block
			return 5
		"Buff":
			if enemy != null and "buff_power" in enemy:
				return enemy.buff_power
			return 2
		"Debuff":
			if enemy != null and "debuff_power" in enemy:
				return enemy.debuff_power
			return 1
		"Charge":
			if enemy != null and "_charge_counter" in enemy:
				return enemy._charge_counter
			return 1
		"MegaAttack":
			return int(entry.get("intent_damage", 0)) * 2
		_:
			return int(entry.get("intent_damage", 0))


func _primary_enemy_widget() -> Control:
	if _enemy_widgets.is_empty():
		return null
	var idx: int = clamp(int(_state.primary_enemy_idx), 0, _enemy_widgets.size() - 1)
	return _enemy_widgets[idx]


func _hover_anchor_for(source: Control) -> Vector2:
	# Tooltip panel size mirrors HoverPreviewView.PANEL_SIZE.
	var panel: Vector2 = Vector2(220, 120)
	var margin: float = 12.0
	var fallback: Vector2 = Vector2(size.x - panel.x - margin, size.y - 480)
	if source == null or not is_instance_valid(source):
		return fallback
	# Anchor the tip directly above the card with a fixed 10px gap.
	# Use the card's RESTING rect (base_pos meta written by hand_ui.gd) so the
	# tip doesn't chase the hover-lift.
	var row: Node = _hand_ui.get_node("Row")
	var card_size: Vector2 = source.size
	var base_local: Vector2 = source.get_meta("base_pos", source.position)
	var row_global: Vector2 = row.global_position
	var card_global_origin: Vector2 = row_global + base_local
	var local_origin: Vector2 = card_global_origin - global_position
	var gap: float = 10.0
	var x: float = local_origin.x + card_size.x * 0.5 - panel.x * 0.5
	x = clamp(x, margin, max(margin, size.x - panel.x - margin))
	var y: float = local_origin.y - panel.y - gap
	if y < margin:
		# Card pinned near the top — flip the tip below instead so it's still readable.
		y = local_origin.y + card_size.y + gap
	return Vector2(x, y)


func _emit_signals_for_new_log_entries(log_before: int, fallback_card: Resource) -> void:
	var entries: Array = _state.trait_fire_log
	for i in range(log_before, entries.size()):
		var entry: Dictionary = entries[i]
		var src: String = entry.get("source", "")
		if src == "reaction":
			_signaler.emit_signal("reaction_triggered", entry.get("id", ""), fallback_card)
		else:
			_signaler.emit_signal(
				"trait_fired",
				entry.get("source_trait_id", ""),
				fallback_card,
				int(entry.get("depth", 0)),
			)


func _on_drops_announced(drops: Array) -> void:
	# Append to run_state.traits_collected so the run picks them up.
	if drops.is_empty():
		return
	for d in drops:
		_run_state.traits_collected.append(d)


# ---------------------------------------------------------------------------
# End-turn summary panel
# ---------------------------------------------------------------------------

func _damage_events_sum_since(before: int) -> int:
	if _state == null or not ("damage_events" in _state):
		return 0
	var events: Array = _state.damage_events
	var total: int = 0
	for i in range(before, events.size()):
		total += int(events[i].get("dmg", 0))
	return total


func _reset_turn_stats() -> void:
	_turn_dmg_dealt = 0
	_turn_dmg_taken = 0
	_turn_kills = 0


func _show_end_turn_summary(current_hp: int, is_battle_end: bool = false) -> void:
	if _summary_panel == null:
		_summary_panel = _build_summary_panel()
		add_child(_summary_panel)
	var content: Label = _summary_panel.get_node("VBox/Content")
	var max_hp: int = int(_state.max_hp) if _state != null else 0
	content.text = "回合结算\n\n击杀数:%d\n造成伤害:%d\n受到伤害:%d\n当前生命:%d / %d" % [
		_turn_kills,
		_turn_dmg_dealt,
		_turn_dmg_taken,
		current_hp,
		max_hp,
	]
	# Configure buttons based on battle state.
	var next_btn: Button = _summary_panel.get_node("VBox/ButtonRow/NextRoundBtn")
	var menu_btn: Button = _summary_panel.get_node("VBox/ButtonRow/MenuBtn")
	if is_battle_end:
		next_btn.visible = false
		menu_btn.text = "返回"  # Single button for battle end
	else:
		next_btn.visible = true
		menu_btn.text = "返回主界面"
	_summary_panel.visible = true
	# Don't auto-hide anymore — player must click a button.


func _hide_summary_panel() -> void:
	if _summary_panel != null and is_instance_valid(_summary_panel):
		_summary_panel.visible = false


func _on_summary_next_round() -> void:
	_hide_summary_panel()
	# Continue to next round — animate dealing the new hand.
	_reset_turn_stats()
	_refresh_without_hand()
	_end_btn.disabled = true  # Disable during animation
	var deck_pos: Vector2 = Vector2(-300, size.y - HAND_HEIGHT * 0.5)
	_hand_ui.animate_deal(_state.hand, _locale, deck_pos, _on_deal_complete)


func _on_summary_return_to_menu() -> void:
	_hide_summary_panel()
	if _finished:
		# Battle ended — emit using stored result.
		var result: Dictionary = get_meta("_battle_result", {"won": false, "drops": [], "hp_left": int(_state.player_hp) if _state != null else 0})
		battle_finished.emit({
			"won":     result.get("won", false),
			"hp_left": int(_state.player_hp) if _state != null else 0,
			"drops":   result.get("drops", []),
		})
	else:
		# Abandon run — return to main menu.
		battle_finished.emit({
			"won":     false,
			"hp_left": int(_state.player_hp) if _state != null else 0,
			"drops":   [],
			"abandoned": true,
		})


func _build_summary_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "EndTurnSummary"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -200
	panel.offset_right = 200
	panel.offset_top = -160
	panel.offset_bottom = 160

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.07, 0.12, 0.95)
	bg.border_color = Color(0.95, 0.85, 0.4, 0.9)
	bg.set_border_width_all(3)
	bg.set_corner_radius_all(12)
	bg.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", bg)

	# VBox for content + buttons
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)

	var label := Label.new()
	label.name = "Content"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.7))
	label.add_theme_font_size_override("font_size", 18)
	vbox.add_child(label)

	# Spacer
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	# Button row
	var hbox := HBoxContainer.new()
	hbox.name = "ButtonRow"
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var next_btn := Button.new()
	next_btn.name = "NextRoundBtn"
	next_btn.text = "进入下一轮"
	next_btn.custom_minimum_size = Vector2(140, 44)
	next_btn.add_theme_font_size_override("font_size", 16)
	next_btn.pressed.connect(_on_summary_next_round)
	hbox.add_child(next_btn)

	var btn_spacer := Control.new()
	btn_spacer.custom_minimum_size = Vector2(20, 0)
	hbox.add_child(btn_spacer)

	var menu_btn := Button.new()
	menu_btn.name = "MenuBtn"
	menu_btn.text = "返回主界面"
	menu_btn.custom_minimum_size = Vector2(140, 44)
	menu_btn.add_theme_font_size_override("font_size", 16)
	menu_btn.pressed.connect(_on_summary_return_to_menu)
	hbox.add_child(menu_btn)

	panel.visible = false
	return panel
