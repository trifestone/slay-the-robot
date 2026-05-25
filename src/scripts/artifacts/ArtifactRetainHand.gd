# Retains all cards in hand at end of turn
extends BaseArtifact

func connect_signals() -> void:
	super()
	Signals.card_drawn.connect(_on_card_drawn)
	Signals.card_add_to_hand_requested.connect(_on_card_add_to_hand_requested)

func _on_player_turn_started():
	super()
	var player_hand: Array[CardData] = Global.player_data.player_hand
	Signals.card_retain_requested.emit(player_hand)

func _on_card_drawn(card_data: CardData):
	var card_retain_request: Array[CardData] = [card_data]	# formatting into card data array
	Signals.card_retain_requested.emit(card_retain_request)

func _on_card_add_to_hand_requested(cards: Array[CardData], _hand_card_count_max: int):
	Signals.card_retain_requested.emit(cards)
