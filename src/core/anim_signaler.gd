## ISSUE-011a — AnimSignaler.
## Thin Node wrapper around the emit() kernel + battle/run lifecycle that
## fires Godot signals at the moments VFX scenes care about:
##
##   reaction_triggered(reaction_id: String, card: Resource)
##   trait_fired(trait_id: String, card: Resource, depth: int)
##   enemy_killed(enemy: Resource, drops: Array)
##
## Pure logic — no rendering, fully headless-testable. Subscribers (the .tscn
## VFX scenes from 011b) connect to the signals and play their animations.
##
## Public API:
##   emit_with_signals(state, event, card)
##         — wraps emit() and inspects state.trait_fire_log delta.
##   notify_enemy_killed(enemy, drops)
##         — call from run.gd / battle_loop.gd at the appropriate moment.
extends Node

const EmitScript := preload("res://core/emit.gd")

signal reaction_triggered(reaction_id: String, card: Resource)
signal trait_fired(trait_id: String, card: Resource, depth: int)
signal enemy_killed(enemy: Resource, drops: Array)
signal enemy_attacked(damage: int)

## Player healed (green float + HP bar bump).
signal player_healed(amount: int)

## Block changed: amount is the delta (positive = gain, negative = loss).
## is_gain true when the player actively gains block (card/play effect).
## is_gain false when block is consumed by enemy attack.
signal block_changed(delta: int, is_gain: bool, remaining: int)

## Shield broke — all block consumed in one hit.
signal shield_broke()

## Player's card lunges forward toward target_idx, then settles.
## Use to drive the attacker pre-strike animation.
signal attacker_lunged(target_idx: int)

## Enemy lunges toward the player when attacking.
## enemy_idx: which enemy in state.enemies is attacking.
signal enemy_lunged(enemy_idx: int)

## Single strike landed on enemy at target_idx. dmg is HP loss after block,
## blocked is the absorbed amount (0 if no resistance).
signal damage_dealt(target_idx: int, dmg: int, blocked: int)

var _emitter: Object = null


func _ready() -> void:
	_emitter = EmitScript.new()


## Run emit() and surface signals based on the new entries appended to
## state.trait_fire_log. Order of signals matches log order.
func emit_with_signals(state: Object, event: int, card: Resource) -> void:
	if _emitter == null:
		_emitter = EmitScript.new()
	var before: int = state.trait_fire_log.size()
	_emitter.emit(state, event, card)
	var after: int = state.trait_fire_log.size()
	for i in range(before, after):
		var entry: Dictionary = state.trait_fire_log[i]
		var src: String = entry.get("source", "")
		if src == "reaction":
			# For reaction entries, "id" holds the override effect string.
			# Use that as a stable identifier for the burst SFX selector.
			emit_signal("reaction_triggered", entry.get("id", ""), card)
		else:
			emit_signal(
				"trait_fired",
				entry.get("source_trait_id", ""),
				card,
				entry.get("depth", 0)
			)


## Caller-side hook: invoke when an enemy's HP drops to <=0 and drops resolved.
## Lets the devour_kill VFX play and the trait-acquired toast show drops.
func notify_enemy_killed(enemy: Resource, drops: Array) -> void:
	emit_signal("enemy_killed", enemy, drops)


## Caller-side hook: invoke after the enemy turn resolves and we know how
## many HP the player lost. Drives the damage-pop VFX on PlayerUI.
func notify_enemy_attacked(damage: int) -> void:
	emit_signal("enemy_attacked", damage)


## Caller-side hook: invoke when an enemy lunges toward player to attack.
## enemy_idx: index of the attacking enemy in state.enemies.
func notify_enemy_lunged(enemy_idx: int) -> void:
	emit_signal("enemy_lunged", enemy_idx)


## Caller-side hook: invoke when the player is healed by any effect.
## Drives the green +N float above the player avatar.
func notify_player_healed(amount: int) -> void:
	emit_signal("player_healed", amount)


## Caller-side hook: invoke when block amount changes.
## delta: positive = gained, negative = consumed.
## is_gain: true when actively gained (card effect), false when consumed (enemy hit).
## remaining: block value after the change.
func notify_block_changed(delta: int, is_gain: bool, remaining: int) -> void:
	emit_signal("block_changed", delta, is_gain, remaining)
	if remaining == 0 and delta < 0:
		emit_signal("shield_broke")
