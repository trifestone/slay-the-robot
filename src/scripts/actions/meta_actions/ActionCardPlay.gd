## A special action used purely to allow some statuses/interceptors to affect card plays
## as they're happening, such as duplicating them.
## This action does nothing and is in fact not even performed, but exists purely to be intercepted right before a card play in Hand.
## If you want to invoke certain cards to be played, use ActionPlayCards to directly trigger
## additional card plays over a given cardset.
## See: ActionCardPlayEnd for an action which is performed, signifying the end of a card play
extends BaseAction
