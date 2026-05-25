## Allows for attaching custom listeners/logic to a card that's currently in hand beyond basic evemts
## already supported by the card itself, such as responding to when other cards are played/discarded/etc
## or other unique events
## These should be used to listen for and generate actions which perform behavior,
## but do not perform behavior on their own
## Managed by Card
## Override
extends RefCounted
class_name BaseCardListener

var parent_card: Card
var card_data: CardData
var values: Dictionary = {}

func _init(_parent_card: Card, _values: Dictionary = {}):
	parent_card = _parent_card
	card_data = parent_card.card_data 
	values = _values
	_connect_signals()
	
func _connect_signals():
	# override in subclasses
	pass
