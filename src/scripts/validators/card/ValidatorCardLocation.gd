# Validator for determining card location in combat (hand, draw, etc)
# see CardPlayRequest.CARD_PLAY_DESTINATIONS and CardData.get_card_location() for more
extends BaseValidator

func _validation(card_data: CardData, _action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	if card_data == null:
		push_error("No card given")
		return false
	
	var card_locations: Array = _get_validator_value("card_locations", values, _action, [CardPlayRequest.CARD_PLAY_DESTINATIONS.DRAW_TOP]) # acceptable locations for the card to be in
	var card_deck_location: int = card_data.get_card_deck_location()
	
	return card_locations.has(card_deck_location)

