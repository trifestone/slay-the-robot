# read only data for performing an action at a rest site
extends SerializableData
class_name RestActionData

@export var rest_action_name: String = ""
@export var rest_action_texture_path: String = ""
@export var rest_actions: Array[Dictionary] = []
@export var rest_action_validators: Array[Dictionary] = [] # validators required for the action to be clickable

enum REST_ACTION_COST_TYPES {
	EXCLUSIVE,	# the action is mututally exclusive with all other exclusive actions
	INCLUSIVE,	# the action can be done once and does not disable other actions
	INCLUSIVE_REPEATABLE, # the action can be done multiple times and does not disable other actions
}
@export var rest_action_cost_type: int = REST_ACTION_COST_TYPES.EXCLUSIVE
