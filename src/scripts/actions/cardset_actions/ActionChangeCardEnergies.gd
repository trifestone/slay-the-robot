# Changes the energy cost values of given cards
extends BaseCardsetAction

func perform_action() -> void:
	var card_energy_cost: int = get_action_value("card_energy_cost", -1)
	var card_energy_cost_until_combat: int = get_action_value("card_energy_cost_until_combat", -1)
	var card_energy_cost_until_played: int = get_action_value("card_energy_cost_until_played", -1)
	var card_energy_cost_until_turn: int = get_action_value("card_energy_cost_until_turn", -1)
	
	var picked_cards: Array[CardData] = _get_picked_cards()
	
	for card_data in picked_cards:
		if card_energy_cost > -1:
			card_data.set_card_energy_cost(card_energy_cost)
		if card_energy_cost_until_combat > -1:
			card_data.set_card_energy_cost_until_combat(card_energy_cost_until_combat)
		if card_energy_cost_until_played > -1:
			card_data.set_card_energy_cost_until_played(card_energy_cost_until_played)
		if card_energy_cost_until_turn > -1:
			card_data.set_card_energy_cost_until_turn(card_energy_cost_until_turn)
