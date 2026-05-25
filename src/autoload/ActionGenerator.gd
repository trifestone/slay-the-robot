## Singleton for generating actions.
## Provides wrappers for common actions used across by the UI and framework.
extends Node

## General use factory method for creating actions.
## Creates and initializes actions from a script path and values.
## Action data is [{"script_path": {values}}].
## NOTE: Not automatically added to the stack and performed; do so with ActionHandler.add_actions()
func create_actions(_parent_combatant: BaseCombatant, _card_play_request: CardPlayRequest, _targets: Array[BaseCombatant], actions_data: Array[Dictionary], _parent_action: BaseAction) -> Array[BaseAction]:
	
	var actions: Array[BaseAction] = []
	
	for action_data in actions_data:
		for action_path in action_data:
			var action_asset = load(action_path)
			var action: BaseAction = action_asset.new()
			
			var action_values: Dictionary[String, Variant] = {}
			action_values.assign(action_data[action_path]) # # assign to force typed dict
			
			action.init(_parent_combatant, _card_play_request, _targets, action_values, _parent_action)
			actions.append(action)
	
	return actions

## Makes a CardPlayEnded action, used in Hand
func generate_card_play_finished(card_play_request: CardPlayRequest) -> BaseAction:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_CARD_PLAY_END: {}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), card_play_request, [], action_data, null)[0]
	
	return generated_action

## Used in Hand to draw cards at the start of a turn
func generate_start_of_turn_draw_actions(number_of_cards: int = PlayerData.PLAYER_CARD_DRAW_PER_TURN) -> void:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_DRAW_GENERATOR: {
			"draw_count": number_of_cards,
			"is_start_of_turn_draw": true # use interceptors checking this flag to adjust number_of_cards
		}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()

## Generates the map for an act using an action, given an act to use.
func generate_act(act_id: String, act_number: int = 1) -> void:
	var act_data: ActData = Global.get_act_data(act_id)
	var action_data: Array[Dictionary] = [{
		act_data.act_action_script_path: {
			"act_id": act_id,
			"act_number": act_number,
			}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()

## Given the player's current act, randomly selects and generates the next act.
func generate_next_act() -> void:
	var act_number: int = Global.player_data.player_act
	var act_data: ActData = Global.get_act_data(Global.player_data.player_act_id)
	
	var rng_act_selection: RandomNumberGenerator = Global.player_data.get_player_rng("rng_act_selection")
	
	if len(act_data.act_next_act_ids) > 0:
		# randomly select the next act type
		var act_next_act_ids: Array[String] = Random.shuffle_array(rng_act_selection, act_data.act_next_act_ids.duplicate())
		var next_act_id: String = act_next_act_ids[0]
		# generate the next act
		generate_act(next_act_id, act_number + 1)
	else:
		push_error("No next acts defined")

## Forces a visit to a given location id using action system.
## Used by Map when selecting a location.
func generate_visit_location(location_id: String, autosave_before_visit = true) -> void:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_VISIT_LOCATION: {
			"location_id": location_id,
			"autosave_before_visit": autosave_before_visit
			}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()

func generate_chest_open() -> void:
	# generate a reward payload, which can be intercepted
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_OPEN_CHEST: {
			"chest_has_money": true,
			"chest_has_artifacts": true,
			"chest_has_consumables": true,
			"chest_has_cards": true,
			
			"chest_generates_money": true,
			"chest_generates_artifacts": true,
			"chest_generates_consumables": true,
			"chest_generates_cards": true,

			"chest_money_amount": 25,
			"chest_artifact_count": 1,
			"chest_consumable_count": 1,
			"chest_card_amount_draft": Global.player_data.reward_drafts,
			"chest_cards_per_draft": Global.player_data.reward_cards_per_draft,
			}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()

## Generates and processes an action to populate a shop with given items and their parallel prices.
## Called from ShopData.visit_shop().
func generate_populate_shop_items(shop_cards: Array[CardData], shop_card_prices: Array[int],
shop_artifact_ids: Array[String], shop_artifact_prices: Array[int], 
shop_consumable_ids: Array[String], shop_consumable_prices: Array[int]) -> void:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_SHOP_POPULATE_ITEMS: {
			"shop_cards": shop_cards,
			"shop_card_prices": shop_card_prices,
			"shop_artifact_ids": shop_artifact_ids,
			"shop_artifact_prices": shop_artifact_prices,
			"shop_consumable_ids": shop_consumable_ids,
			"shop_consumable_prices": shop_consumable_prices,
			}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()



## Forces a combat start that can be intercepted.
## If event_object_id is empty, uses current location's event.
func generate_combat_start(event_object_id: String) -> void:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_START_COMBAT: {
			"event_object_id": event_object_id
			}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()


func generate_use_consumable(selected_target: BaseCombatant, consumable_slot_index: int) -> void:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_USE_CONSUMABLE: {
			"consumable_slot_index": consumable_slot_index
			}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [selected_target], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()

## Generates an instant interceptable action to decay a status. Used by BaseCombatant.
func generate_decay_status_effect(selected_target: BaseCombatant, status_effect_object_id: String, decay_amount: int) -> void:
	var action_data: Array[Dictionary] = [{
		Scripts.ACTION_DECAY_STATUS: {
			"status_effect_object_id": status_effect_object_id,
			"status_charge_amount": decay_amount
			}
		}]
	var generated_action: BaseAction = ActionGenerator.create_actions(Global.get_player(), null, [selected_target], action_data, null)[0]
	
	# immediately process this action without ActionHandler
	generated_action.perform_action()
