# a utility object for Combat to allow asynchronous turn ending with hierarchical levels of end turn immediacy
# if a higher level of immediacy is detected in Combat a new object will be created, replacing the await
extends RefCounted
class_name CombatEndTurn

var _combat = null	# the parent combat ui node, just used for a callback
var _hand = null
enum END_TURN_QUEUE_IMMEDIACY {	# Do not rearrange
	WAIT_FOR_ALL_CARD_PLAYS,
	WAIT_FOR_ACTIONS,
	IMMEDIATE
	}
var end_turn_queue_immediacy: int = END_TURN_QUEUE_IMMEDIACY.WAIT_FOR_ALL_CARD_PLAYS

func _init(combat, hand, _end_turn_queue_immediacy = END_TURN_QUEUE_IMMEDIACY.WAIT_FOR_ALL_CARD_PLAYS):
	_combat = combat
	_hand = hand
	end_turn_queue_immediacy = _end_turn_queue_immediacy

func wait() -> void:
	match end_turn_queue_immediacy:
		END_TURN_QUEUE_IMMEDIACY.IMMEDIATE:
			# forces the turn to instantly end, removing all remaining card plays and actions
			_hand.refund_card_queue()
			ActionHandler.clear_all_actions()
			end_turn()
		END_TURN_QUEUE_IMMEDIACY.WAIT_FOR_ACTIONS:
			# prevents further card plays but finishes the rest of the current action stack
			_hand.refund_card_queue()
			Signals.disable_hand_requested.emit(true)
			if ActionHandler.actions_being_performed:
				await ActionHandler.actions_ended
			end_turn()
		END_TURN_QUEUE_IMMEDIACY.WAIT_FOR_ALL_CARD_PLAYS, _:
			# default
			# continuously wait for all card plays to finish before ending the player's turn
			Signals.disable_hand_requested.emit(true)
			while len(_hand.card_play_queue) > 0 or ActionHandler.actions_being_performed:
				await ActionHandler.actions_ended
			end_turn()

func disable():
	_combat = null

func end_turn():
	if _combat != null:
		_combat.end_turn_animation()
