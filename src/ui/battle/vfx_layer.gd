## ISSUE-024 — VFXLayer: subscribes to an AnimSignaler and plays the
## matching .tscn FX over the enemy widget when reaction_triggered,
## trait_fired, or enemy_killed fires.
##
## Public API:
##   bind(signaler, enemy_widgets: Array, player_ui: Control = null) -> void
##   play_heal(amount: int, target: Control) -> void
##
## Signals:
##   drops_announced(drops: Array)  — fired right after the devour_kill VFX
##                                    so BattleScene can show a toast.
extends Control

const ReactionBurstScene := preload("res://vfx/reaction_burst.tscn")
const DevourKillScene    := preload("res://vfx/devour_kill.tscn")
const HealPopScene       := preload("res://vfx/heal_pop.tscn")

const ENEMY_BURST_OFFSET: Vector2 = Vector2(-10, -16)
const TRAIT_BURST_OFFSET: Vector2 = Vector2(0, 16)

const SHAKE_AMPLITUDE: float = 8.0
const SHAKE_DURATION: float = 0.32
const LUNGE_DISTANCE: float = 36.0
const LUNGE_DURATION: float = 0.12

const RESIST_COLOR := Color(0.55, 0.75, 1.0)
const DAMAGE_COLOR := Color(1, 0.45, 0.45)

signal drops_announced(drops: Array)

var _signaler: Node = null
var _enemy_widgets: Array = []
var _player_ui: Control = null
var _player_lunge_dir: float = 1.0  # +1 lunges right (toward enemies)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Connect the signaler's signals. Safe to re-bind across battles.
## enemy_widgets : Array[Control] — one widget per state.enemies entry, in order.
## player_ui     : optional, when provided enemy_attacked spawns a damage pop on it.
func bind(signaler: Node, enemy_widgets, player_ui: Control = null) -> void:
	_disconnect_all()
	_signaler = signaler
	# Accept either a Control (legacy single-target) or an Array of Controls.
	if typeof(enemy_widgets) == TYPE_ARRAY:
		_enemy_widgets = enemy_widgets.duplicate()
	elif enemy_widgets is Control:
		_enemy_widgets = [enemy_widgets]
	else:
		_enemy_widgets = []
	_player_ui = player_ui
	if _signaler == null:
		return
	if _signaler.has_signal("reaction_triggered"):
		_signaler.reaction_triggered.connect(_on_reaction_triggered)
	if _signaler.has_signal("trait_fired"):
		_signaler.trait_fired.connect(_on_trait_fired)
	if _signaler.has_signal("enemy_killed"):
		_signaler.enemy_killed.connect(_on_enemy_killed)
	if _signaler.has_signal("enemy_attacked"):
		_signaler.enemy_attacked.connect(_on_enemy_attacked)
	if _signaler.has_signal("attacker_lunged"):
		_signaler.attacker_lunged.connect(_on_attacker_lunged)
	if _signaler.has_signal("damage_dealt"):
		_signaler.damage_dealt.connect(_on_damage_dealt)


## Replace the bound enemy widget list (e.g. after a target shift) without
## tearing down the signal connections.
func update_enemy_widgets(widgets: Array) -> void:
	_enemy_widgets = widgets.duplicate()


## Spawn a +N heal float at the target widget's center.
func play_heal(amount: int, target: Control) -> void:
	var pop: Node2D = HealPopScene.instantiate()
	add_child(pop)
	pop.position = _center_of(target)
	pop.play(Vector2.ZERO, amount)


## Pin the player's lunge direction toward the enemy row. Sign is +1 if the
## enemy row is to the right of the player, -1 otherwise. Defaults to +1.
func set_player_lunge_dir_from(player: Control, enemy_anchor: Control) -> void:
	if player == null or enemy_anchor == null:
		_player_lunge_dir = 1.0
		return
	var dx: float = enemy_anchor.global_position.x - player.global_position.x
	_player_lunge_dir = -1.0 if dx < 0.0 else 1.0


# ---------------------------------------------------------------------------
# Signal handlers
# ---------------------------------------------------------------------------

func _on_reaction_triggered(reaction_id: String, _card: Resource) -> void:
	var burst: Node2D = ReactionBurstScene.instantiate()
	add_child(burst)
	var rect: Rect2 = _enemy_rect(_primary_widget(), ENEMY_BURST_OFFSET)
	burst.play(rect, reaction_id, 1.0)


func _on_trait_fired(trait_id: String, _card: Resource, _depth: int) -> void:
	var burst: Node2D = ReactionBurstScene.instantiate()
	add_child(burst)
	var rect: Rect2 = _enemy_rect(_primary_widget(), TRAIT_BURST_OFFSET)
	rect.size = Vector2(140, 60)
	burst.play(rect, trait_id, 0.6)


func _on_enemy_killed(enemy: Resource, drops: Array) -> void:
	var dk: Node2D = DevourKillScene.instantiate()
	add_child(dk)
	var enemy_name: String = ""
	if enemy != null and "id" in enemy:
		enemy_name = String(enemy.id)
	dk.play(_enemy_rect(_primary_widget(), Vector2.ZERO), enemy_name, drops, 1.2)
	drops_announced.emit(drops)


func _on_enemy_attacked(damage: int) -> void:
	if damage <= 0:
		return
	var target: Control = _player_ui
	if target == null:
		return
	var pop: Node2D = HealPopScene.instantiate()
	add_child(pop)
	var anchor: Vector2 = _center_of(target) + Vector2(0, -target.size.y * 0.5 - 8.0)
	pop.play_damage(anchor, damage, 1.0)
	_shake(target, SHAKE_AMPLITUDE * 0.7, SHAKE_DURATION)
	_flash(target, DAMAGE_COLOR, 0.25)


## Lunge the PLAYER widget toward the enemy row when the player plays an
## attack card. We deliberately don't push the target enemy here — the
## defender already gets shake + damage flash via _on_damage_dealt, and
## tweening the same `position` property on the enemy from two handlers
## fights with itself (lunge + shake clobber each other).
func _on_attacker_lunged(_target_idx: int) -> void:
	if _player_ui == null:
		return
	_lunge(_player_ui, _player_lunge_dir)


func _on_damage_dealt(target_idx: int, dmg: int, blocked: int) -> void:
	var target: Control = _widget_at(target_idx)
	if target == null:
		return
	if blocked > 0:
		_spawn_resist(target, blocked)
	if dmg > 0:
		_spawn_damage_float(target, dmg)
		_shake(target, SHAKE_AMPLITUDE, SHAKE_DURATION)
		_flash(target, DAMAGE_COLOR, 0.18)


# ---------------------------------------------------------------------------
# Tween helpers
# ---------------------------------------------------------------------------

func _flash(target: Control, color: Color, duration: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var original: Color = target.modulate
	target.modulate = color
	var tw: Tween = create_tween()
	tw.tween_property(target, "modulate", original, duration)


func _shake(target: Control, amp: float, duration: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_meta("base_pos_vfx"):
		target.set_meta("base_pos_vfx", target.position)
	var base_pos: Vector2 = target.get_meta("base_pos_vfx", target.position)
	var step: float = duration / 6.0
	var tw: Tween = create_tween()
	tw.tween_property(target, "position", base_pos + Vector2(amp, 0), step)
	tw.tween_property(target, "position", base_pos + Vector2(-amp, 0), step)
	tw.tween_property(target, "position", base_pos + Vector2(amp * 0.6, 0), step)
	tw.tween_property(target, "position", base_pos + Vector2(-amp * 0.4, 0), step)
	tw.tween_property(target, "position", base_pos, step * 2)


func _lunge(target: Control, dir: float = -1.0) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not target.has_meta("base_pos_vfx"):
		target.set_meta("base_pos_vfx", target.position)
	var base_pos: Vector2 = target.get_meta("base_pos_vfx", target.position)
	var sign: float = -1.0 if dir < 0.0 else 1.0
	var tw: Tween = create_tween()
	tw.tween_property(target, "position", base_pos + Vector2(LUNGE_DISTANCE * sign, 0), LUNGE_DURATION)
	tw.tween_property(target, "position", base_pos, LUNGE_DURATION * 1.5)


func _spawn_resist(target: Control, blocked: int) -> void:
	# Reuse the heal-pop scene with custom color & label so we don't need new VFX assets.
	var pop: Node2D = HealPopScene.instantiate()
	add_child(pop)
	var anchor: Vector2 = _center_of(target) + Vector2(0, -16)
	if pop.has_method("play_resist"):
		pop.play_resist(anchor, blocked, 0.9)
	else:
		# Fallback: piggy-back on play_damage with a custom color/label combo.
		pop.position = anchor
		pop.modulate = RESIST_COLOR
		if pop.has_method("play_damage"):
			pop.play_damage(anchor, blocked, 0.9)
		elif pop.has_method("play"):
			pop.play(Vector2.ZERO, blocked)
	# Ring burst around the shield to read as resistance.
	var burst: Node2D = ReactionBurstScene.instantiate()
	add_child(burst)
	var rect: Rect2 = _enemy_rect(target, Vector2.ZERO)
	rect.size = Vector2(120, 60)
	if burst.has_method("play"):
		burst.play(rect, "resist", 0.5)


func _spawn_damage_float(target: Control, dmg: int) -> void:
	var pop: Node2D = HealPopScene.instantiate()
	add_child(pop)
	var anchor: Vector2 = _center_of(target) + Vector2(0, 4)
	if pop.has_method("play_damage"):
		pop.play_damage(anchor, dmg, 0.9)
	elif pop.has_method("play"):
		pop.play(Vector2.ZERO, dmg)


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _enemy_rect(widget: Control, offset: Vector2) -> Rect2:
	if widget == null or not is_instance_valid(widget):
		return Rect2(offset, Vector2(160, 220))
	# Widgets live in EnemyRow / PlayerUI containers — translate via globals so
	# the rect lands correctly inside the full-screen VFXLayer.
	var origin: Vector2 = _to_layer_local(widget.global_position)
	var size: Vector2 = widget.size
	var center: Vector2 = origin + (size * 0.5) + offset
	return Rect2(center - (size * 0.5), size)


func _widget_at(idx: int) -> Control:
	if _enemy_widgets.is_empty():
		return null
	if idx < 0 or idx >= _enemy_widgets.size():
		return _primary_widget()
	var w = _enemy_widgets[idx]
	if w is Control and is_instance_valid(w):
		return w
	return null


func _primary_widget() -> Control:
	for w in _enemy_widgets:
		if w is Control and is_instance_valid(w):
			return w
	return null


func _center_of(c: Control) -> Vector2:
	if c == null or not is_instance_valid(c):
		return Vector2.ZERO
	# Convert from screen/global space to VFXLayer-local space, otherwise
	# damage floats land in whichever ancestor's local frame the widget lives.
	return _to_layer_local(c.global_position + (c.size * 0.5))


func _to_layer_local(p_global: Vector2) -> Vector2:
	# Control has no `to_local`; subtract our own global origin instead.
	return p_global - global_position


func _disconnect_all() -> void:
	if _signaler == null:
		return
	if _signaler.has_signal("reaction_triggered") and _signaler.reaction_triggered.is_connected(_on_reaction_triggered):
		_signaler.reaction_triggered.disconnect(_on_reaction_triggered)
	if _signaler.has_signal("trait_fired") and _signaler.trait_fired.is_connected(_on_trait_fired):
		_signaler.trait_fired.disconnect(_on_trait_fired)
	if _signaler.has_signal("enemy_killed") and _signaler.enemy_killed.is_connected(_on_enemy_killed):
		_signaler.enemy_killed.disconnect(_on_enemy_killed)
	if _signaler.has_signal("enemy_attacked") and _signaler.enemy_attacked.is_connected(_on_enemy_attacked):
		_signaler.enemy_attacked.disconnect(_on_enemy_attacked)
	if _signaler.has_signal("attacker_lunged") and _signaler.attacker_lunged.is_connected(_on_attacker_lunged):
		_signaler.attacker_lunged.disconnect(_on_attacker_lunged)
	if _signaler.has_signal("damage_dealt") and _signaler.damage_dealt.is_connected(_on_damage_dealt):
		_signaler.damage_dealt.disconnect(_on_damage_dealt)


func _exit_tree() -> void:
	_disconnect_all()
