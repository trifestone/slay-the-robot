# Upgrades all cards that can be upgraded in given cardset
# This can target a list of cards, or their parent cards (making it permanent if in player's deck)
extends BaseCardsetAction

func perform_action():
	var upgrade_parent_card: bool = get_action_value("upgrade_parent_card", true)
	var picked_cards: Array[CardData] = _get_picked_cards()
	
	# iterate over the cards, upgrading them and/or their parent
	for card_data in picked_cards:
		card_data.upgrade_card()
		# potentially upgrade parent if it exists
		if upgrade_parent_card and card_data.parent_card != null:
			card_data.parent_card.upgrade_card()

func _to_string():
	return "Upgrade Card Action"
