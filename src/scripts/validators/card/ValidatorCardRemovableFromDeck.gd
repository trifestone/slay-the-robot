# Validator for if the given card can be removed from permanent deck or not
extends BaseValidator

func _validation(card_data: CardData, _action: BaseAction, values: Dictionary[String, Variant]) -> bool:
	if card_data == null:
		push_error("No card given")
		return false
	
	return not card_data.card_unremovable_from_deck
