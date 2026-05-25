## Base class for any action which requires selecting cards from either the hand, deck, or a pile.
## Extend to provide functionality.
## This action will be passed to Hand, CardSelectionOverlay, or CardDraftSelectionOverlay and modified with the selected cards
## Override perform_async_action() to actually perform the action once the cards are selected and passed into picked_cards
## See ActionPickCards subclass for instead deferring logic to child cardset actions, which provides more flexibility.
extends BaseAsyncAction
class_name ActionBasePickCards

## The final cards picked automatically or by the player. Child actions of this will typically use
## this value.
var picked_cards: Array[CardData] = []

enum CARD_PICK_TYPES {	# THE TYPE OF DRAFT. DETERMINES THE UI USED FOR THE PICKING AND THE CARD INPUT SOURCE TO USE
	# hand selection ui
	HAND,
	# deck selection ui
	DECK,	# The player's source deck. Typically used for selecting cards to permanently modify
	COMBAT_DECK,	# The cards across the copied deck of the player in combat
	DRAW,
	DISCARD,
	EXHAUST,
	PLAYED_THIS_TURN,
	PLAYED_LAST_TURN,
	# draft selection ui
	DRAFT,
	}

# helper contant used to see if the deck ui picking should be used
const DECK_PICK_TYPES: Array = [	
	CARD_PICK_TYPES.DECK,
	CARD_PICK_TYPES.COMBAT_DECK,
	CARD_PICK_TYPES.DRAW,
	CARD_PICK_TYPES.DISCARD,
	CARD_PICK_TYPES.EXHAUST,
	CARD_PICK_TYPES.PLAYED_THIS_TURN,
	CARD_PICK_TYPES.PLAYED_LAST_TURN,
	]

### Override These

func perform_async_action() -> void:
	# override this to provide functionality after the player or game has picked the cards
	# picked_cards will be populated at this point and you can manipulate them
	action_async_finished.emit()

## Gets the display message for the user when picking cards.
## Uses card_pick_text from card's values.
## Formatted string of {0} for max cards, {1} for cards picked, and {2} for cards remaining.
## override for messages requiring different formatting
func get_card_pick_text() -> String:
	var max_card_amount: int = get_card_pick_max_amount()
	var picked_card_amount: int = len(picked_cards)
	var remaining_card_amount: int = max_card_amount - picked_card_amount
	var pickable_cards_max_amount: int = get_pickable_cards_max_amount()
	
	var card_pick_text: String = get_action_value("card_pick_text", "Choose {0} card(s). {1} cards selected")
	var returned_text: String = card_pick_text.format([max_card_amount, picked_card_amount, remaining_card_amount, pickable_cards_max_amount])
	return returned_text

func _to_string():
	return "Base Card Pick Action"

### Keep

func get_input_cardset() -> Array[CardData]:
	# these are the source of cards you pick from, before additional validators are applied
	# defaults to getting the player hand
	# support drafting cards
	var card_pick_type: int = get_card_pick_type()
	
	# can inject cards to select from via draft_cards
	# useful for RewardOverlay which pre-generates card rewards
	var pick_draft_cards: bool = get_action_value("pick_draft_cards", false)
	if pick_draft_cards:
		var draft_cards: Array[CardData] = []
		draft_cards.assign(get_action_value("draft_cards", []))
		if len(draft_cards) > 0:
			return draft_cards
		else:
			push_error("No Provided Draft Cards")
			return draft_cards
	
	# can generate random cards to pick from
	# mainly useful for combat
	var draft_from_card_pool: bool = get_action_value("draft_from_card_pool", false)

	if draft_from_card_pool:
		return get_drafted_cards()
	
	return Global.player_data.get_pile(card_pick_type)

func perform_action():
	# determine if its possible to select the cards from the input card set
	# the number of min cards and min requirement determine if the action is performable
	# and if its automatically performed
	var pickable_cards: Array[CardData] = get_pickable_cards() # automatically obtain list of pickable cards from an input set
	
	# card selection params
	var min_cards_are_required: bool = get_min_cards_are_required_for_action()
	var random_selection: bool = get_action_value("random_selection", false) 	# to select the cards randomly without player input
	var min_card_amount: int = get_card_pick_min_amount()
	
	if len(pickable_cards) < min_card_amount:
		# not enough cards
		if min_cards_are_required:
			# not enough cards to perform the card action, do nothing
			await Global.get_tree().process_frame # add a delay to allow ActionHandler to catch up with async to avoid infinite hang
			action_async_finished.emit()
			return
		else:
			# automatically select the cards
			picked_cards = pickable_cards
			await Global.get_tree().process_frame # add a delay to allow ActionHandler to catch up with async to avoid infinite hang
			perform_async_action()
			return
	elif len(pickable_cards) == min_card_amount:
		# exactly enough cards; automatically select them
		picked_cards = pickable_cards
		await Global.get_tree().process_frame # add a delay to allow ActionHandler to catch up with async to avoid infinite hang
		perform_async_action()
		return
	else:
		# more than min cards
		if random_selection:
			# automatically randomly select the cards
			var rng_name: String = get_action_value("rng_name", "rng_card_picking")
			var rng_card_picking: RandomNumberGenerator = Global.player_data.get_player_rng(rng_name)
			
			# randomize card order and pick first X cards
			pickable_cards = Random.shuffle_array(rng_card_picking, pickable_cards)
			picked_cards = pickable_cards.slice(0, min_card_amount)

			await Global.get_tree().process_frame # add a delay to allow ActionHandler to catch up with async to avoid infinite hang
			perform_async_action()
			return
		else:
			# prompt the user for card input
			async_awaiting = true 
			Signals.card_pick_requested.emit(self)
			await Signals.card_pick_confirmed
			async_awaiting = false
			perform_async_action()
			return

### Card Picking

## Some support for drafting random cards, such as cards that generate random cards in
## combat that the player can then select.
## NOTE: This is typically not useful for general card rewards because generation happens at time of
## action and is not saved.
## Still useful for generating random cards in combat, or generating rewards through
## deterministic criteria (eg pick a rare card from all rare cards)
## You may use a predefined card pack, use the card pool available to the player,
## or filter all cards using validator criteria.
func get_drafted_cards() -> Array[CardData]:
	var filtered_card_draft: Array[CardData] = []
	
	# a specific card pack to use
	# for complex queries you may wish to generate a card pack specific for the draft rather
	# than narrowing from all cards with validators each time
	var draft_card_pack_id: String = get_action_value("draft_card_pack_id", "")
	
	# use the cards that the player is capable of drafting, from PlayerData
	var draft_use_player_draft: bool = get_action_value("draft_use_player_draft", false)
	
	# randomize ordering and reduce to a max number of cards
	var rng_name: String = get_action_value("rng_name", "rng_non_reward_card_drafting")
	var rng_non_reward_card_drafting: RandomNumberGenerator = Global.player_data.get_player_rng(rng_name)
	var draft_max_card_amount: int = get_action_value("draft_max_card_amount", 3) # 0 or negative for all cards. Use DECK card pick type for larger ui selections
	
	if draft_card_pack_id != "":
		#TODO support weighting for card pack based drafting
		filtered_card_draft = Random.generate_unweighted_card_draft_from_card_pack_id(rng_non_reward_card_drafting, draft_card_pack_id, draft_max_card_amount)
	elif draft_use_player_draft:
		# generate a draft from player available cards
		# can be weighted or unweighted
		# NOTE: validator_data should be empty for this kind of draft or it may break the
		# draft once it hits get_pickable_cards() and runs the validator over them
		var draft_probability_is_weighted: bool = get_action_value("draft_is_weighted", false)
		var draft_use_pity_system: bool = get_action_value("draft_use_pity_system", false)
		if draft_probability_is_weighted:
			filtered_card_draft = Random.generate_rarity_weighted_card_draft(rng_non_reward_card_drafting, draft_max_card_amount, Random.CARD_DRAFT_TABLE_TYPES.STANDARD, draft_use_pity_system)
		else:
			filtered_card_draft = Random.generate_unweighted_card_draft(rng_non_reward_card_drafting, draft_max_card_amount)	
	else:
		# generate a draft from all cards and narrow using validators
		var card_validator_data: Array = get_card_pick_validator_data()
		
		var card_ids: Array[String] = CardFilter.new().filter_card_validators(card_validator_data).convert_to_unique_card_object_ids()
		card_ids = Random.shuffle_slice_array(rng_non_reward_card_drafting, card_ids, draft_max_card_amount)
		# generate the card instances
		filtered_card_draft = Global.get_card_data_from_prototypes(card_ids)
	
	return filtered_card_draft

### Picking Validation Methods

## Validates if manual selection will automatically confirm when maximum number of cards are picked.
## Especially useful for when there's only 1 card.
func is_quick_pick() -> bool:
	var quick_pick: bool = get_action_value("quick_pick", true)
	if quick_pick:
		var picked_card_amount: int = len(picked_cards)
		return len(picked_cards) >= get_card_pick_max_amount()
	return false

func get_card_pick_type() -> int:
	return get_action_value("card_pick_type", CARD_PICK_TYPES.HAND)
	
func get_card_pick_validator_data() -> Array:
	# returns validators applied to any cards the user can pick
	return get_action_value("validator_data", [])

## The number of cards needed to be selected or the following actions will not be performed
func get_min_cards_are_required_for_action() -> int:
	return get_action_value("min_cards_are_required_for_action", false)

## The minimum number of cards required for this card pick to be 
func get_card_pick_min_amount() -> int:
	return get_action_value("min_card_amount", 0)

func get_card_pick_max_amount() -> int:
	return get_action_value("max_card_amount", PlayerData.PLAYER_DEFAULT_HAND_CARD_COUNT_MAX)

## Gets how many cards are available after a card filter is applied. Useful for things like
## getting first X cards from top of discard/draw pile
func get_pickable_cards_max_amount() -> int:
	return get_action_value("pickable_cards_max_amount", -1)

func get_pickable_cards() -> Array[CardData]:
	# gets all cards that meet pickable criteria from a given input list of cards
	# this factors in additonal validators that can be supplied
	var input_cardset: Array[CardData] = get_input_cardset()
	var pickable_cards: Array[CardData] = []
	var parent_card: CardData = null
	if card_play_request != null:
		parent_card = card_play_request.card_data
	
	# filter out cards that fail validation
	pickable_cards = CardFilter.new(input_cardset).filter_card_validators(get_card_pick_validator_data()).filtered_cards
	# ignore the card that generated this action
	pickable_cards.erase(parent_card)
	
	# limits the selection to the first N results. Eg: first 3 attack cards from draw pile
	# instead of showing all attack cards in draw pile
	var pickable_cards_max_amount: int = get_pickable_cards_max_amount()
	if pickable_cards_max_amount > 0 and len(pickable_cards) >= pickable_cards_max_amount:
		pickable_cards = pickable_cards.slice(0, pickable_cards_max_amount)
	
	return pickable_cards

func are_enough_cards_picked() -> bool:
	var min_card_amount: int = get_card_pick_min_amount()
	var max_card_amount: int = get_card_pick_max_amount()
	var picked_card_amount: int = len(picked_cards)
	return (min_card_amount <= picked_card_amount) and (picked_card_amount <= max_card_amount)  

func is_card_pickable(card_data: CardData) -> bool:
	# optionally override this 
	# method for determining if a given card can be selected for this action
	# for example limiting the player to only picking cards that are above an energy cost
	var max_card_amount: int = min(get_card_pick_max_amount(), PlayerData.PLAYER_DEFAULT_HAND_CARD_COUNT_MAX)
	if len(picked_cards) >= max_card_amount:
		return false
	
	# run card through validators, should return either empty array or contain the card
	var card_validator_data: Array = get_card_pick_validator_data()
	var validated_card: Array[CardData] = CardFilter.new([card_data]).filter_card_validators(card_validator_data).filtered_cards
	if len(validated_card) == 0:
		return false
		
	return true	# by default all cards are pickable

## Forces the card pick to end
func force_action_end() -> void:
	if async_awaiting:
		picked_cards = []
		Signals.card_pick_confirmed.emit()
		async_awaiting = false
