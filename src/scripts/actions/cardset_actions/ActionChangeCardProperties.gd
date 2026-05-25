## General use cardset action that changes CardData properties (not card_values!)
## to a given value using set(), overwriting existing values.
## This can target a list of cards, or their parent cards (making it permanent if in player's deck)
## See ActionImproveCardValues for additive version that affects card_values
extends BaseCardsetAction

func perform_action():
	var change_parent_card: bool = get_action_value("change_parent_card", true)
	var picked_cards: Array[CardData] = _get_picked_cards()
	
	for card_data in picked_cards:
		# get parent card if changing that that
		var parent_card_data: CardData = null
		if change_parent_card:
			if card_data.parent_card == null:
				push_error("No parent card found")
			else:
				parent_card_data = card_data.parent_card

		var card_properties: Dictionary[String, Variant] = {}
		card_properties.assign(get_action_value("card_properties", {})) # assign to force typed dict
	
		if card_data != null:
			card_data.set_card_properties(card_properties)
		if parent_card_data != null:
			parent_card_data.set_card_properties(card_properties)

func _to_string():
	return "Change Card Properties Action"
