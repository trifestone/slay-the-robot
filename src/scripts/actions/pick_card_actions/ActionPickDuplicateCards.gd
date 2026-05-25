# Action to pick cards then duplicate them, populating them into picked_cards
# Should have children cardset actions to ensure the duplicated cards are placed somewhere
extends ActionPickCards

func perform_async_action() -> void:
	var generated_cards: Array[CardData]
	for card in picked_cards:
		var duplicated_card: CardData = card.get_prototype(true)
		generated_cards.append(generated_cards)
	
	# overwrite picked_cards action value with the generated cards, for child cardset actions
	# NOTE: this does not affect this action's picked_cards field which is the original picked cards
	values["picked_cards"] = generated_cards
	
	_generate_child_actions()
	action_async_finished.emit()

	# emit signals for each created card
	for card_data: CardData in picked_cards:
		Signals.card_created.emit(card_data)
