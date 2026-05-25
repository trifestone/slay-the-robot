# read only data for a type of status effect
extends SerializableData
class_name StatusEffectData

#region General
@export var status_effect_name: String = ""	# how this status appears in tooltips
@export var status_effect_script_path: String = "res://scripts/status_effects/BaseStatusEffect.gd"	# script of the BaseStatusEffect determining behavior of the status
@export var status_effect_stacks: bool = true	# whether or not the status effect can have multiple charges
@export var status_effect_can_be_negative: bool = false	# determines whether to remove the status when negative charges happen
@export var status_effect_allows_multiples: bool = false	# whether or not the status effect can be applied multiple times uniquely. If false only 1 can exist

@export var status_effect_texture_path: String = ""	# display texture path for the status
@export var status_effect_negative_charges_texture_path: String = ""	# optional texture for if the status is negative
@export var status_effect_is_visible: bool = true	# if the status should be displayed to the player

enum STATUS_EFFECT_TYPES {BUFF, DEBUFF, NEUTRAL}
@export var status_effect_type: int = STATUS_EFFECT_TYPES.BUFF	# if the game considers this status positive, negative, or neutral

#endregion

#region Status Actions
## The actions perfomed if the player has the status. See: BaseAction.perform_status_actions().
@export var status_effect_player_actions: Array[Dictionary] = []
## The actions perfomed an emey has the status. See: BaseAction.perform_status_actions()
@export var status_effect_enemy_actions: Array[Dictionary] = []

## When a status effect should be processed relative to the others. Higher numbers processed earlier.
@export var status_effect_priority: int = 0


enum STATUS_EFFECT_PROCESS_TIMES {
	PRE_DRAW_PLAYER_START_TURN, # Actions taken before the player has drawn cards
	POST_DRAW_PLAYER_START_TURN, # Actions taken after the player has drawn cards (but before they can act)
	PLAYER_END_TURN, # Actions taken after the player has ended their turn but before enemy turns
	ENEMY_START_TURN, # Actions taken before the enemy has performed an intent
	ENEMY_END_TURN, # Actions taken after enemy intent
	}

## Indicates when the effect should proc. This can control when and for what entities a status effect applies.
## NOTE: Having a status time for both enemy and player simply means it will work for both enemies and players,
## not that a player status will affect an enemy. Eg a poison like effect given to player end turn and enemy
## start turn will mean poisoned players take damage at end of turn, and poisoned enemies take damage on the
## start of their turn, not that a poisoned player will damage both the enemy and themself.
@export var status_effect_action_process_times: Array[int] = [
	STATUS_EFFECT_PROCESS_TIMES.PRE_DRAW_PLAYER_START_TURN,
	STATUS_EFFECT_PROCESS_TIMES.ENEMY_END_TURN,
]

#endregion


#region Healthbar
enum STATUS_EFFECT_HEALTHBAR_RESERVE_TYPES {
	ZERO,
	STATUS_CHARGES,
	STATUS_SECONDARY_CHARGES,
	}
## Controls what value the status effect should reserve the healthbar with
@export var status_effect_healthbar_reserve_type: int = STATUS_EFFECT_HEALTHBAR_RESERVE_TYPES.ZERO
## If the status effect is reserved in the healthbar, it will appear as this html color. Can be empty
@export var status_effect_healthbar_layer_color: String = ""

#endregion

#region Status Decay

## How fast the status decays linearly, if it does so. Typically 0 to negative value. 
## Positive values will increase the charges.
## WARNING: Statuses decay after their actions have been performed. If you do not 
## define status_effect_action_process_times then it will not know when to decay the status,
## even for actions that don't do anything during turn phases.
@export var status_effect_decay_rate: int = 0

enum STATUS_EFFECT_DECAY_TYPES {
	LINEAR,
	# cuts charges in half
	# NOTE: This does not play nicely with statuses that allow duplicates. Only use non linear amounts on
	# non duplicate statuses
	HALF_LIFE_ROUND_UP, # rounding up means it can never become 0
	HALF_LIFE_ROUND_DOWNN,
	}
@export var status_effect_decay_type: int = STATUS_EFFECT_DECAY_TYPES.LINEAR

#endregion


@export var status_effect_interceptor_ids: Array[String] = []
