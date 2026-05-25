## BattleState — carries per-battle and per-turn mutable state for emit().
## Extended in ISSUE-005 with full combat fields: HP, energy, deck/hand/discard,
## enemy, turn counter, phase FSM, RNG, and battle log.
##
## Fields required by ADR-001 / ISSUE-003 acceptance criteria:
##   fire_depth     : current OnTraitFired recursion depth (0 = top-level emit)
##   trait_fire_log : ordered Array of Dictionaries recording each trait fire
##   cooldown_table : Dictionary keyed by "<card_instance_id>/<trait_id>" → fire count this turn
##
## reactions : Array of Reaction resources loaded from data/reactions.json.
##             Populated by the caller before the first emit() of a battle.
extends RefCounted

# ---------------------------------------------------------------------------
# Phase enum (enum FSM — path 2, no external addon required)
# PlayerTurn / EnemyTurn / Resolution / GameOver map to spec §4.7 sub-states.
# ---------------------------------------------------------------------------
enum Phase {
	PLAYER_TURN,
	ENEMY_TURN,
	RESOLUTION,
	GAME_OVER,
}

# ---------------------------------------------------------------------------
# State fields (ADR-001 §决策 1-3)
# ---------------------------------------------------------------------------

## Recursion depth tracker for OnTraitFired chain.
## 0 = original emit (e.g. OnPlay), 1 = first OnTraitFired bubble,
## 2 = second bubble (max allowed), 3+ = silently blocked.
var fire_depth: int = 0

## Ordered log of every trait (or reaction override) that fired this battle.
## Each entry is a Dictionary:
##   { "source": "trait"|"reaction", "id": String,
##     "card_iid": int, "event": int, "depth": int,
##     "effect_type": String, "effect_value": int, "source_trait_id": String }
var trait_fire_log: Array = []

## Per-turn fire-count table.
## Key:   "<card_instance_id>/<trait_id>"   (String)
## Value: int — number of times this trait has fired this turn on this card.
var cooldown_table: Dictionary = {}

## Reaction list for this battle. Populated by the caller.
## Each element is a Reaction Resource (from data/reaction.gd).
var reactions: Array = []

# ---------------------------------------------------------------------------
# ISSUE-005 combat fields
# ---------------------------------------------------------------------------

## Player current hit points.
var player_hp: int = 0

## Player maximum hit points.
var max_hp: int = 0

## Current energy available this turn.
var energy: int = 0

## Maximum energy regenerated at the start of each turn (PRD §4.2: 3).
var max_energy: int = 3

## Draw pile — Array of TraitCard Resources.
var deck: Array = []

## Cards currently in the player's hand — Array of TraitCard Resources.
var hand: Array = []

## Discard pile — Array of TraitCard Resources.
var discard: Array = []

## The enemy resource for this battle (TraitEnemy).
## With the multi-enemy migration (post ISSUE-023b), this mirrors
## enemies[primary_enemy_idx]["enemy"] for back-compat with single-enemy
## tests and UI bindings.
var enemy: Resource = null

## Enemy current hit points (mirrors enemies[primary_enemy_idx]["hp"]).
var enemy_hp: int = 0

## Array of enemy entries for multi-enemy encounters.
## Each entry: { "enemy": TraitEnemy, "hp": int, "max_hp": int, "intent_damage": int }
## start_battle() always populates this with at least one entry, so consumers
## can treat enemies as the source of truth and enemy/enemy_hp as a primary
## target view kept in sync by sync_primary_enemy() / sync_primary_hp_into_entry().
var enemies: Array = []

## Index of the primary target (the enemy that gets hit by single-target attacks).
## Advanced by advance_primary_if_dead() when the current primary dies.
var primary_enemy_idx: int = 0

## Per-strike damage events appended by BattleLoop._apply_damage_to_primary.
## The UI consumes the new tail after each play_card / end_turn so it can
## spawn one VFX (lunge/shake/blocked-float) per strike.
## Entry: { "idx": int, "dmg": int, "blocked": int }
var damage_events: Array = []

## Turn counter. Incremented at the start of each new player turn.
var turn: int = 0

## Current battle phase (Phase enum value).
var phase: int = Phase.PLAYER_TURN

## Seeded RNG for deterministic shuffles.
var rng: RandomNumberGenerator = null

## Human-readable battle log. One line appended per meaningful action.
## Used for golden-hash regression testing.
var battle_log: Array[String] = []

# ---------------------------------------------------------------------------
# Reset hooks
# ---------------------------------------------------------------------------

## Call once at the start of a new battle.
## Clears all per-battle state including depth, log, cooldowns, and reactions.
func reset_per_battle() -> void:
	fire_depth    = 0
	trait_fire_log = []
	cooldown_table = {}
	reactions      = []


## Call at the start of each new turn (both player and enemy turns).
## Resets cooldown counts so per-turn limits apply freshly each turn.
func reset_per_turn() -> void:
	cooldown_table = {}


## Populate state.reactions from the ReactionRegistry.
## Call once after reset_per_battle() and before the first emit() of a battle.
func setup_reactions() -> void:
	var registry = preload("res://core/reaction_registry.gd").new()
	reactions = registry.load_all()


# ---------------------------------------------------------------------------
# Multi-enemy helpers
# ---------------------------------------------------------------------------

## Sync the primary-view fields (enemy / enemy_hp) from enemies[primary_enemy_idx].
## Call after any change to enemies[primary_enemy_idx]["hp"] or after the
## primary index advances.
func sync_primary_enemy() -> void:
	if enemies.is_empty():
		enemy = null
		enemy_hp = 0
		return
	primary_enemy_idx = clamp(primary_enemy_idx, 0, enemies.size() - 1)
	var entry: Dictionary = enemies[primary_enemy_idx]
	enemy = entry.get("enemy", null)
	enemy_hp = int(entry.get("hp", 0))


## Push the primary-view enemy_hp value back into enemies[primary_enemy_idx].
## Call after direct mutation of enemy_hp (e.g. tests or damage application)
## so the entries array stays authoritative.
func sync_primary_hp_into_entry() -> void:
	if enemies.is_empty():
		return
	var idx: int = clamp(primary_enemy_idx, 0, enemies.size() - 1)
	var entry: Dictionary = enemies[idx]
	entry["hp"] = max(0, int(enemy_hp))
	enemies[idx] = entry


## Returns true if every entry in enemies has hp <= 0.
func all_enemies_dead() -> bool:
	if enemies.is_empty():
		return enemy_hp <= 0
	for entry in enemies:
		if int(entry.get("hp", 0)) > 0:
			return false
	return true


## Advance primary_enemy_idx forward to the next alive entry.
## Re-syncs the primary-view fields. No-op if no alive enemies remain.
func advance_primary_if_dead() -> void:
	if enemies.is_empty():
		return
	if int(enemies[primary_enemy_idx].get("hp", 0)) > 0:
		return
	for i in range(enemies.size()):
		if int(enemies[i].get("hp", 0)) > 0:
			primary_enemy_idx = i
			sync_primary_enemy()
			return
	# No alive enemies — leave indexes alone but refresh view (hp=0).
	sync_primary_enemy()
