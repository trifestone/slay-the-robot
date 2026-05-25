# Action to exhaust selected cards
extends BaseCardsetAction

func perform_action() -> void:
	var picked_cards: Array[CardData] = _get_picked_cards()
	Signals.card_exhaust_requested.emit(picked_cards)
