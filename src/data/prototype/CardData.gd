# Prototyped data object containing all information on a card
extends PrototypeData
class_name CardData

var parent_card: CardData = null	# the parent card in the player's true deck that this one was copied from. This is used for cards copied from the player's deck in combat. This is not the prototype the card is made from. This should only ever be one layer deep at most. Mainly used for meta scaling cards.
@export var card_name: String = ""
@export var card_description: String = ""
@export var card_texture_path: String = ""
@export var card_keyword_object_ids: Array[String] = [] # keywords (mechanics with tooltips) displayed when this card is hovered over
@export var card_color_id: String = "color_green"

### Card Energy
# card energies
@export var card_energy_cost: int = 1 : set = set_card_energy_cost # The raw energy cost of the card before modifiers. Generally shadowed by the others. See: get_card_energy_cost()
@export var card_energy_cost_until_played: int = -1	: set = set_card_energy_cost_until_played # can shadow card_energy_cost. -1 means no shadowing
@export var card_energy_cost_until_turn: int = -1	: set = set_card_energy_cost_until_turn # can shadow card_energy_cost. -1 means no shadowing
@export var card_energy_cost_until_combat: int = -1	: set = set_card_energy_cost_until_combat # can shadow card_energy_cost. -1 means no shadowing. Allows for changing card costs while keeping original cost intact
# variable energy cost
@export var card_energy_cost_is_variable: bool = false	# if card costs all energy to play, for X cost cards
@export var card_energy_cost_variable_upper_bound: int = -1	# allows an upper bound on energy input into an X cost card. -1 for no limit

@export var card_first_shuffle_priority: int = 0	# Determines how card should be shuffled in the deck on combat start. Typically 1,0,-1. Positive values drawn first

### Card Type
enum CARD_TYPES {ATTACK, SKILL, POWER, STATUS, CURSE}
const STANDARD_CARD_TYPES: Array[int] = [CARD_TYPES.ATTACK, CARD_TYPES.SKILL, CARD_TYPES.POWER]
const NON_REUSABLE_CARD_TYPES: Array[int] = [CARD_TYPES.POWER]	# card types that when played will not be moved into a pile
@export var card_type: int = CARD_TYPES.ATTACK

### Card Rarity
enum CARD_RARITIES {BASIC, COMMON, UNCOMMON, RARE, GENERATED}
const STANDARD_CARD_RARITIES: Array[int] = [CARD_RARITIES.COMMON, CARD_RARITIES.UNCOMMON, CARD_RARITIES.RARE]
@export var card_rarity: int = CARD_RARITIES.COMMON

## Make false to prevent cards with this object_id from appearing in card packs. This only takes effect
## once during initial runtime and is useful to prevent cards from appearing without giving them GENERATED rarity
## or explicitly listing them by ID in packs. Essentially just an extensibility feature with niche application.
## See: CardPackData.create_card_pack_card_filter()
@export var card_appears_in_card_packs: bool = true

### Card Play Flags
@export var card_is_playable: bool = true
@export var card_exhausts: bool = false	# card moved to exhaust pile instead of discard when played
@export var card_is_ethereal: bool = false	# card exhausted if not played
@export var card_is_retained: bool = false	# if the card innately stays in hand end of turn

@export var card_requires_target: bool = true	# card requires user to select a target to play it


### Card Values
@export var card_values: Dictionary = {}	# values on the card like attack/block amount. These are fallback values used by the card's actions and can be modified
@export var card_description_preview_overrides: Array[Array] = [ # adds ability to inject more values/custom values to intercept beyond basic automatic damage/block calculations
	# ["damage", Scripts.ACTION_ATTACK],	# 2 parameters: value_name + intercecpted action
	# ["damage", Scripts.ACTION_ATTACK, "damage_1"], # Optional third parameter for mapping custom values
]

### Card Actions
@export var card_play_actions: Array[Dictionary] = [
	#{
	#Scripts.ACTION_ATTACK_GENERATOR: {"damage": 5, "number_of_attacks": 2, "time_delay": 0.0}
	#}
]
@export var card_discard_actions: Array[Dictionary] = []	# actions that trigger when card is manually discarded
@export var card_end_of_turn_actions: Array[Dictionary] = []	# actions that trigger when the card is in hand end of turn
@export var card_exhaust_actions: Array[Dictionary] = []	# actions that trigger when card is exhausted
@export var card_draw_actions: Array[Dictionary] = []	# actions that trigger when card is drawn and added to hand
@export var card_retain_actions: Array[Dictionary] = []	# actions that trigger when card is retained at the end of turn
@export var card_right_click_actions: Array[Dictionary] = []	# actions that trigger when card is right clicked while in hand
@export var card_initial_combat_actions: Array[Dictionary] = []	# actions that trigger at the start of combat for each card in the deck

@export var card_add_to_deck_actions: Array[Dictionary] = []	# actions that trigger when card is added to player's permanent deck 
@export var card_remove_from_deck_actions: Array[Dictionary] = []	# actions that trigger when card is removed from player's permanent deck
@export var card_transform_in_deck_actions: Array[Dictionary] = []	# actions that trigger when card is transformed in player's permanent deck

## Validators required for the card to be playable. Will make the card glow if all pass.
@export var card_play_validators: Array[Dictionary] = [
	#{"validator_script_path.gd": {"validator_value_1": Variant}}
]
## Validators that make the card glow. If empty then card_play_validators will be used for glow.
## Useful for cards with bonus conditional effects.
@export var card_glow_validators: Array[Dictionary] = []
@export var card_listeners: Array[Dictionary] = [	
	#{
	#"res://scripts/actions/BaseCardListener.gd": {values}
	#}
]	# allows attaching custom behavior to a card in hand beyond hand basic actions
## Optional tags that can be applied to a card to filter them arbitrarily, or apply them in combat
## as some kind of invisible token. Used in ValidatorCardTag.
## Updated via add_card_tag() and remove_card_tag().
@export var card_tags: Array[String] = [
	#"tag_<something>"
]

### Upgrades
@export var card_upgrade_amount: int = 0	# number of times the card has been upgraded
@export var card_upgrade_amount_max: int = 1	# max number of times the card can be upgraded
@export var card_first_upgrade_property_changes: Dictionary[String, Variant] = { # applies .set() to these properties on first upgrade
	
}
@export var card_upgrade_value_improvements: Dictionary[String, int] = { # applies improve_card_values() each upgrade
	
}

### Deck Flags
@export var card_unremovable_from_deck: bool = false	# if the card cannot be removed from the permanent deck. Does nothing by itself, this should be enforced through validators
@export var card_untransformable_from_deck: bool = false	# if the card cannot be transformed from the permanent deck. Does nothing by itself, this should be enforced through validators

func _to_string():
	return get_card_name()

func get_card_name() -> String:
	if card_upgrade_amount > 0:
		if card_upgrade_amount > 1:
			return card_name + "+" + str(card_upgrade_amount - 1)
		else:
			return card_name + "+"
	else:
		return card_name

func get_card_deck_location() -> int:
	# gets where the card exists in combat
	var player_data: PlayerData = Global.player_data
	if player_data.player_hand.has(self):
		return CardPlayRequest.CARD_PLAY_DESTINATIONS.HAND
	if player_data.player_discard.has(self):
		return CardPlayRequest.CARD_PLAY_DESTINATIONS.DISCARD
	if player_data.player_exhaust.has(self):
		return CardPlayRequest.CARD_PLAY_DESTINATIONS.EXHAUST
	if player_data.player_draw.has(self):
		# draw pile uses draw top
		return CardPlayRequest.CARD_PLAY_DESTINATIONS.DRAW_TOP
	
	return CardPlayRequest.CARD_PLAY_DESTINATIONS.BANISH # not in play

func get_card_energy_cost(shadow_energy_cost: bool = true, variable_cost_is_zero: bool = false) -> int:
	# allows shadowing energy costs
	
	# variable cost cards may be treated as either all energy or zero
	if card_energy_cost_is_variable:
		if variable_cost_is_zero:
			return 0
		else:
			if card_energy_cost_variable_upper_bound < 0:
				# variable cost cards with no upper bound
				return Global.player_data.player_energy
			else:
				return max(min(Global.player_data.player_energy, card_energy_cost_variable_upper_bound), 0)
	# shadowing
	if shadow_energy_cost:
		if card_energy_cost_until_played > -1:
			return card_energy_cost_until_played
		if card_energy_cost_until_turn > -1:
			return card_energy_cost_until_turn
		if card_energy_cost_until_combat > -1:
			return card_energy_cost_until_combat
	return card_energy_cost

func set_card_energy_cost(energy_cost: int) -> void:
	var cost: int = max(0, energy_cost)
	if card_energy_cost != cost:
		card_energy_cost = cost
		Signals.card_properties_changed.emit(self)

func set_card_energy_cost_until_played(energy_cost: int) -> void:
	if energy_cost != card_energy_cost_until_played:
		card_energy_cost_until_played = energy_cost
		Signals.card_properties_changed.emit(self)

func set_card_energy_cost_until_turn(energy_cost: int) -> void:
	if energy_cost != card_energy_cost_until_turn:
		card_energy_cost_until_turn = energy_cost
		Signals.card_turn_energy_changed.emit(self)

func set_card_energy_cost_until_combat(energy_cost: int) -> void:
	if energy_cost != card_energy_cost_until_combat:
		card_energy_cost_until_combat = energy_cost
		Signals.card_properties_changed.emit(self)

func get_card_description() -> String:
	var modified_card_description: String = card_description
	for key in card_values.keys():
		modified_card_description = modified_card_description.replace("["+key+"]", str(card_values[key]))
	
	return modified_card_description

func set_card_properties(card_properties: Dictionary[String, Variant]) -> void:
	for property_name: String in card_properties:
		set(property_name, card_properties[property_name])
	Signals.card_properties_changed.emit(self)

func improve_card_values(card_value_improvements: Dictionary[String, int]) -> void:
	# iterate over the card's values, adding to them where necessary
	for key_name in card_value_improvements.duplicate(true).keys():
		var improve_by_value: Variant = card_value_improvements[key_name] # get the modifier to improve the base value by
		if card_values.has(key_name):
			# add to existing value
			if improve_by_value is int:
				# add numbers to numbers
				card_values[key_name] = max(0, card_values[key_name] + improve_by_value	)
			if improve_by_value is Dictionary:
				# add all parallel dictionary keys
				if card_values[key_name] is Dictionary:
					for sub_key_name in improve_by_value:
						card_values[key_name][sub_key_name] = max(0, card_values[key_name][sub_key_name] + improve_by_value[sub_key_name])
		else:
			# overwrite non existing keys
			card_values[key_name] = improve_by_value
	
	Signals.card_properties_changed.emit(self)

func upgrade_card() -> void:
	# upgrades a card, overwriting properities and improving any card values
	
	# check if upgrade possible
	if card_upgrade_amount < card_upgrade_amount_max:
		# overwrite CardData's own properties on the first upgrade
		if card_upgrade_amount == 0:
			for property_name in card_first_upgrade_property_changes.keys():
				var property_value: Variant = card_first_upgrade_property_changes[property_name]
				set(property_name, property_value)
		
		# improve card values each upgrade
		improve_card_values(card_upgrade_value_improvements)
		card_upgrade_amount += 1
		
		Signals.card_upgraded.emit(self)

func transform_card(new_card_object_id: String) -> void:
	# transforms a card, overwriting the values of a card with that of a new card prototype id's values
	var old_uid: String = object_uid
	var card_data: CardData = Global.get_card_data_from_prototype(new_card_object_id)
	var exported_properties: Dictionary = card_data.get_serializable_properties()
	for property_name in exported_properties.keys():
		var property_value: Variant = exported_properties[property_name]
		set(property_name, property_value)
	
	object_uid = old_uid # preserve the uid between transforms
	Signals.card_transformed.emit(self)

func add_card_tag(card_tag: String) -> void:
	if not card_tags.has(card_tag):
		card_tags.append(card_tag)
func remove_card_tag(card_tag: String) -> void:
	card_tags.erase(card_tag)
