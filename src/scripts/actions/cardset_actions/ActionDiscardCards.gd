# Discards picked cards
extends BaseCardsetAction

func perform_action() -> void:
	var picked_cards: Array[CardData] = _get_picked_cards()
	Signals.card_discard_requested.emit(picked_cards, true)
