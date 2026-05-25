# implements basic interface for a status effect's logical component
# see StatusEffect for ui element that uses it
extends RefCounted
class_name BaseStatusEffect

var status_effect_data: StatusEffectData
var parent_combatant: BaseCombatant

var status_charges: int = 0 : set = set_status_charges
var status_secondary_charges: int = 0 # typically denotes intensity of the status, when status_charges is used as a timer
var status_custom_values: Dictionary = {} # any unique values the status uses

func init(_status_effect_data, _parent_combatant: BaseCombatant):
	status_effect_data = _status_effect_data
	parent_combatant = _parent_combatant
	_connect_signals()

## Override this to provide connections to other signals for statuses with custom events
## NOTE: Do not connect to start and end turn signals
func _connect_signals() -> void:
	pass

## Status action logic
## Override for custom logic or conditionals
## Called from BaseCombatant.perform_status_effect_actions()
func perform_status_effect_actions() -> void:
	# get actions to perform
	var action_data: Array[Dictionary] = []
	if parent_combatant.is_in_group("players"):
		action_data = status_effect_data.status_effect_player_actions
	else:
		action_data = status_effect_data.status_effect_enemy_actions
	
	# perform them
	if len(action_data) > 0:
		var card_play_request: CardPlayRequest = _generate_status_effect_card_play_request() # generate a fake request
		var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(parent_combatant, card_play_request, [parent_combatant], action_data, null)
		ActionHandler.add_actions(generated_actions)

## Factory method to make a fake card play request and pass in status effect related data into it
## Actions can then alias these with the custom_key_names parameter of BaseAction to pass them as parameters
func _generate_status_effect_card_play_request() -> CardPlayRequest:
	var card_play_request: CardPlayRequest = CardPlayRequest.new()
	card_play_request.card_values = {
		"invoking_status_effect": self, # this is used to get a reference to this status object, if desired. Useful for grabbing status_custom_values
		"invoking_status_effect_object_id": status_effect_data.object_id,
		"invoking_status_effect_charges": status_charges,
		"invoking_status_effect_secondary_charges": status_secondary_charges
	}
	return card_play_request

### Status Charges

func add_status_charges(charge_amount: int) -> void:
	status_charges = status_charges + charge_amount

func set_status_charges(value: int):
	# provides setter validation of a status's charge bounds
	var lower_bound: int = 0
	var upper_bound: int = 1
	if status_effect_data.status_effect_can_be_negative:
		lower_bound = -999
	if status_effect_data.status_effect_stacks:
		upper_bound = 999
	
	# add charges and clamp within bounds
	status_charges = clamp(value, lower_bound, upper_bound)

## Optional Override
## Certain statuses will reserve chunks of the healthbar visually.
## Use this to get how much that is for each status that inflicts damage
## Typically just returns 0, status_charges or status_secondary_charges, but may have conditional logic
func get_status_healthbar_reserved_amount() -> int:
	match status_effect_data.status_effect_healthbar_reserve_type:
		StatusEffectData.STATUS_EFFECT_HEALTHBAR_RESERVE_TYPES.ZERO:
			return 0
		StatusEffectData.STATUS_EFFECT_HEALTHBAR_RESERVE_TYPES.STATUS_CHARGES:
			return status_charges
		StatusEffectData.STATUS_EFFECT_HEALTHBAR_RESERVE_TYPES.STATUS_SECONDARY_CHARGES:
			return status_secondary_charges
	return 0

## Optional Override
## Tells BaseCombatant how much to decay the status after this status has been invoked.
## You may wish to override to supply conditional decay logic.
## NOTE: In the case of statuses that allow duplicates it is strongly advised to only use linear
## decay rates with non conditional decay as the first status determines the decay rate for the others
## which may produce unintended results.
func get_status_decay_amount() -> int:
	# figure out how much to decay by and generate an instant interceptable action to decay by that amount
	var decay_amount: int = status_effect_data.status_effect_decay_rate # defaults to linear decay
	# non linear decay
	match status_effect_data.status_effect_decay_type:
		StatusEffectData.STATUS_EFFECT_DECAY_TYPES.HALF_LIFE_ROUND_UP:
			decay_amount = -1 * int(floor(float(status_charges) * 0.5)) # since the value is subtracted, floor() means rounding up
		StatusEffectData.STATUS_EFFECT_DECAY_TYPES.HALF_LIFE_ROUND_DOWNN:
			decay_amount = -1 * int(ceil(float(status_charges) * 0.5)) # since the value is subtracted, ceil() means rounding down
			
	return decay_amount
