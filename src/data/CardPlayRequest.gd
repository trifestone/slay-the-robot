## A data payload for requesting a card play through Hand.
## Stored in Hand in a queue and in Actions as a value/targeting reference.
## In other parts of the code it may be used as a holder of values to pass into action payloads with
## card_values if no card is provided, for actions without cards that need shared dynamic values.
extends RefCounted
class_name CardPlayRequest

var card_data: CardData = null
var selected_target: BaseCombatant = null	# the target the player selected for this play, can be null
var card_values: Dictionary = {}	# a duplicated version of the card's values for the duration of the card play, which can be freely modified without affecting the parent card
var refundable_energy: int = 0	# how much energy the card play can refund if interrupted
var input_energy: int = 0	# how much energy is input into the card play. Can be positive even if refundable_energy is 0. Useful for X cost cards and card play duplications
var is_duplicate_play: bool = false	# duplcate plays should not be further duplicated

## The state of the hand at time of play. This is useful for certain validators that need to know hand state
## since it will include the played card (if it was played from hand) while it would otherwise exist
## in limbo.
var hand_at_play_time: Array[CardData] = []

## NOTE: This is a very awkward enum that unfortunately needs to exist somewhere. See Hand._play_card().
## These don't *really* determine where the card goes, but serve as an enum for locations of where
## cards are/can be, *except* for a few actions where DRAW_BOTTOM/INSERT/TOP are used.
## You may wish to refactor by removing CardData.card_exhausts and having a card_destination property
## using this enum instead along with "power" cards banishing themselves.
enum CARD_PLAY_DESTINATIONS {
	DISCARD, # top of discard pile
	EXHAUST,
	DRAW_BOTTOM, # bottom of draw pile
	DRAW_INSERT, # random location in draw pile
	DRAW_TOP, # top of draw pile. Also used to refer to draw pile in general
	HAND, # attempts to return to hand after play
	BANISH, # not sent anywhere, effectively removing the card from play
	}
var destination: int = CARD_PLAY_DESTINATIONS.DISCARD # where the card goes after being played
