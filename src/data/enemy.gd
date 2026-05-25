## TraitEnemy Resource — describes an enemy's identity and the traits it carries.
## Named TraitEnemy to avoid collision with the upstream Slay-the-Robot Enemy class.
class_name TraitEnemy
extends Resource

## Unique identifier, e.g. "skeleton_grunt".
@export var id: String = ""

## Intent string: "Attack" | "Block" | "Buff" | "Debuff" (StS-style).
@export var intent: String = "Attack"

## Traits this enemy carries (dropped on kill per drop_count).
@export var carried_traits: Array = []  # Array[Trait]

## How many traits this enemy drops on death.
## Normal: 1, Elite: 2, Boss: 3.
@export var drop_count: int = 1

## Damage dealt by this enemy's basic attack each turn.
## Read by battle_loop._get_intent_damage(); defaults to BattleLoop.DEFAULT_INTENT_DAMAGE
## when absent. Tier baselines: Normal 5, Elite 9, Boss 14.
@export var intent_damage: int = 5
