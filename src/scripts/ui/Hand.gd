## UI component that serves as a container for Card objects and provides card playing interface
extends Control

## Controls the movement speed (time) of cards, making them tween faster or slower around the hand
const CARD_TWEEN_TIME: float = 0.2

### General Nodes
@onready var player: BaseCombatant = $%Player
@onready var combat = $%Combat

# a debugging component for displaying hand's physical size
# should be the same size and position of Hand
@onready var hand_size_exceeded_rect: ColorRect = %HandSizeExceededRect
const HAND_EXCEEDED_COLOR: Color = Color.RED
const HAND_NOT_EXCEEDED_COLOR: Color = Color.LIGHT_GREEN

### Card Picking
@onready var card_picking: Control = $%CardPicking
@onready var card_picking_label: Label = $%CardPicking/CardPickLabel
@onready var confirm_pick_button: Button = $%CardPicking/ConfirmPickButton

var current_card_pick_action: ActionBasePickCards = null	# an action currently requesting cards from the player to select. If null clicking cards plays them

### Targeting
@onready var background_button: TextureButton = $%BackgroundButton
@onready var select_target_label: Label = $%SelectTargetLabel
var current_selected_card: Card = null	# used for cards with targeting

### Card Play Queue
var card_play_queue: Array[CardPlayRequest] = []	# array of cards to play
var card_play_queue_reserved_energy_total: int = 0	# used to determine how much energy player is using
var cards_being_played: bool = false
var CARD_NO_ENERGY_COST: int = -1
var hand_disabled: bool = false	# the player cannot play additional cards manually
var performing_card_right_click: bool = false	# flag used to lock card plays while a right click action happens

### Retain
var cards_retained_this_turn: Array[CardData] = []

### Energy this turn
var cards_with_modified_turn_energy: Array[CardData] = []	# keeps track of cards that have their per turn energy modified, to reset at end of turn

### Mapping
var card_data_to_hand_card: Dictionary[CardData, Card] = {} # maps a CardData object to the actual Card represented by it in hand

### Card Positions and Rotations
# Curve controlling card index in hand to its rotation
@export var hand_card_rotation_curve: Curve = preload("res://misc/curves/hand_rotation_curve.tres")
const HAND_CARD_ROTATION_CURVE_MULTIPLIER: float = 6.0 # multiplies the curve sampling

# Curve controlling card index in hand to its y offset
@export var hand_card_y_offset_curve: Curve = preload("res://misc/curves/hand_y_curve.tres")
const HAND_CARD_Y_OFFSET_CURVE_MULTIPLIER: float = -20.0 # multiplies the curve sampling

const CARD_WIDTH: float = 144.0 # how big the Card asset is. NOTE: Update this if you update Card's size at all
const CARD_SEPERATION_WIDTH: float = CARD_WIDTH * .75 # how far apart each card should be from one another. Generally between .5 to 1X the card width

const MIDDLE_OFFSET: float = CARD_WIDTH / 2
var middle: float = (size[0] / 2) - MIDDLE_OFFSET # calculate middle X position of hand container, with optional offset for fine tuning

# y offsets for when the player hovers over a card
const CARD_UNHOVERED_HEIGHT = 0.0
const CARD_HOVERED_HEIGHT = -30

const CARD_PICK_POSITIONS: Array = [
	[0.0],
	[-0.5, 0.5],
	[-1, 0.0, 1],
	[-1.5 ,-0.75, 0.75 ,1.5],
	[-1.5, -0.75, 0.0, 0.75 ,1.5],
	[-2.25, -1.5, -0.75, 0.75 ,1.5, 2.25],
	[-2.25, -1.5, -0.75, 0.0, 0.75 ,1.5, 2.25],
	[-2.75, -2.25, -1.5, -0.75, 0.75 ,1.5, 2.25, 2.75],
	[-2.75, -2.25, -1.5, -0.75, 0.0, 0.75 ,1.5, 2.25, 2.75],
	[-3.25, -2.75, -2.25, -1.5, -0.75, 0.75 ,1.5, 2.25, 2.75, 3.25],
]
const CARD_PICK_Y_OFFSET = -300 # Where picked cards in hand appear relative to the Hand container


func _ready():
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.run_ended.connect(_on_run_ended)

	Signals.player_killed.connect(_on_player_killed)
	
	Signals.card_played.connect(_on_card_played)
	Signals.card_turn_energy_changed.connect(_on_card_turn_energy_changed)
	
	Signals.card_play_requested.connect(_on_card_play_requested)
	Signals.card_pick_requested.connect(_on_card_pick_requested)
	Signals.card_pick_confirmed.connect(_on_card_pick_confirmed)
	
	Signals.card_add_to_hand_requested.connect(_on_card_add_to_hand_requested)
	Signals.card_add_to_draw_requested.connect(_on_card_add_to_draw_requested)
	Signals.card_draw_requested.connect(_on_card_draw_requested)
	Signals.card_discard_requested.connect(_on_card_discard_requested)
	Signals.card_exhaust_requested.connect(_on_card_exhaust_requested)
	Signals.card_banish_requested.connect(_on_card_banish_requested)
	Signals.card_retain_requested.connect(_on_card_retain_requested)
	Signals.reshuffle_requested.connect(_on_reshuffle_requested)
	
	Signals.disable_hand_requested.connect(_on_disable_hand_requested)
	
	Signals.enemy_clicked.connect(_on_enemy_clicked)
	Signals.enemy_hovered.connect(_on_enemy_hovered)
	
	confirm_pick_button.button_up.connect(_on_confirm_pick_button_up)
	
	background_button.button_up.connect(_on_background_button_up)
	
## Recalculates the transforms of Card objects in hand and tweens them to their new positions.
func tween_hand():
	var cards_in_hand: Array[Card] = get_player_hand_cards()
	
	### Figure out the number of cards in hand for figuring out offsets. Picking cards will adjust this number
	var hand_card_count: int = len(cards_in_hand)
	var picked_card_count: int = 0
	if current_card_pick_action != null:
		picked_card_count = len(current_card_pick_action.picked_cards)
		hand_card_count -= picked_card_count
	
	### Calculate dimensions of all the cards in player hand and a modified card seperation value
	var all_cards_width := CARD_SEPERATION_WIDTH * hand_card_count
	var card_x_seperation: float = CARD_SEPERATION_WIDTH
	hand_size_exceeded_rect.color = HAND_NOT_EXCEEDED_COLOR # used for debugging

	# throttle seperation width of cards if it begins to exceed the size of the Hand container
	var hand_width: float = size.x
	if all_cards_width > hand_width:
		card_x_seperation *= (size.x / all_cards_width) # make the seperation a proportion of the exceeded size and the size of the Hand container
		hand_size_exceeded_rect.color = HAND_EXCEEDED_COLOR
	
	### Recalculate new positions/rotations for each card and tween them
	var hand_index: int = 0	# counter for number of cards in hand
	var pick_index: int = 0 # counter for number of cards picked
	
	for card in cards_in_hand:
		# values of rotation and position after calculations
		var new_position: Vector2 = Vector2()
		var new_rot: float = 0.0
		
		# figure out if the card is in hand or picked
		var is_card_in_hand: bool = true
		if current_card_pick_action != null:
			if current_card_pick_action.picked_cards.has(card.card_data):
				is_card_in_hand = false
		
		# calculate new transforms
		if is_card_in_hand:
			if hand_card_count == 1:
				# a single card in hand is made to be in middle with an offset, looks weird otherwise
				new_rot = 0
				new_position = Vector2(middle + (CARD_WIDTH / 2), 0)
			else:
				# rotation
				new_rot = 0
				var rotation_multiplier: float = hand_card_rotation_curve.sample(1.0 / (hand_card_count - 1) * hand_index)
				new_rot = HAND_CARD_ROTATION_CURVE_MULTIPLIER * rotation_multiplier
				# y position
				var card_y_offset: float = hand_card_y_offset_curve.sample(1.0 / (hand_card_count - 1) * hand_index)
				card_y_offset *= HAND_CARD_Y_OFFSET_CURVE_MULTIPLIER
				# x position
				var card_index_offset: float = float(hand_index) - (float(hand_card_count) / 2.0) + 1.0
				var card_x_offset: float = middle + (card_x_seperation * card_index_offset)
				# final position
				new_position = Vector2(card_x_offset, card_y_offset)
			
			hand_index += 1
		else:
			# card not in hand
			new_position = Vector2(middle + CARD_SEPERATION_WIDTH * CARD_PICK_POSITIONS[picked_card_count - 1][pick_index], CARD_PICK_Y_OFFSET)
			new_rot = 0
			pick_index += 1
		
		# interpolate card to new position and rotation
		var tween: Tween = create_tween()
		tween.tween_property(card.pivot, "position", new_position, CARD_TWEEN_TIME)
		var tween_2: Tween = create_tween()
		tween_2.tween_property(card.pivot, "rotation_degrees", new_rot, CARD_TWEEN_TIME)


func _on_card_hovered(card: Card):
	for child in get_children():
		if card == child:
			child.position.y = CARD_HOVERED_HEIGHT
			child.z_index = 1
		else:
			child.position.y = CARD_UNHOVERED_HEIGHT
			child.z_index = 0

func _on_card_unhovered(_card: Card):
	for child in get_children():
		child.position.y = CARD_UNHOVERED_HEIGHT
		child.z_index = 0

func _on_card_selected(card: Card):
	# card clicked, attempt to do something with it
	# check if playing or picking cards
	if current_card_pick_action == null:
		### playing
		# cannot play cards with a disabled hand
		if hand_disabled:
			return
		# cannot play while right click actions happening
		if performing_card_right_click:
			return
		# check if card is generally playable
		if not card.can_play_card():
			return
		# cannot play cards already queued
		for card_play_request in card_play_queue:
			if card_play_request.card_data == card.card_data:
				return
		
		# check if autoplaying card based on targeting type
		if card.card_data.card_requires_target:
			current_selected_card = card
			_prompt_target(card)
		else:
			# generate the card play request and enqueue it
			var card_play_request: CardPlayRequest = CardPlayRequest.new()
			card_play_request.card_data = card.card_data
			card_play_request.selected_target = null
			card_play_request.card_values = card.card_data.card_values.duplicate(true)	# copy the card's values into the card play request
	
			add_card_to_play_queue(card_play_request, true, false)
			current_selected_card = null
			_unprompt_target()
	else:
		### picking
		attempt_pick_card(card)
		
func _on_card_right_clicked(card: Card):
	current_selected_card = null
	_unprompt_target()
	if ActionHandler.actions_being_performed:
		return # cannot right click while actions happening
	if hand_disabled:
		return # cannot right click cards with a disabled hand
	if len(card_play_queue) > 0:
		return # cannot right click cards while cards queued
	_perform_card_right_click_actions(card)

### Targeting

func _on_background_button_up():
	current_selected_card = null
	_unprompt_target()

func _on_enemy_clicked(enemy: Enemy):
	if current_selected_card != null:
		_unprompt_target()
		
		# generate the card play request and enqueue it
		var card_play_request: CardPlayRequest = CardPlayRequest.new()
		card_play_request.card_data = current_selected_card.card_data
		card_play_request.selected_target = enemy
		card_play_request.card_values = current_selected_card.card_data.card_values.duplicate(true)	# copy the card's values into the card play request
	
		
		add_card_to_play_queue(card_play_request, true, false)
		current_selected_card = null

func _on_enemy_hovered(enemy: Enemy):
	if current_selected_card != null:
		current_selected_card.update_card_display(enemy)

func _prompt_target(_card: Card):
	select_target_label.visible = true

func _unprompt_target():
	select_target_label.visible = false

### Playing Cards

func _play_card(card_play_request: CardPlayRequest) -> void:
	
	if card_play_request == null:
		return
	if card_play_request.card_data == null:
		breakpoint
		return	
	
	# store the state of the hand at play time in the play request
	card_play_request.hand_at_play_time = Global.player_data.player_hand.duplicate(false)
	
	# generate dummy card play action and intercept it
	# this allows some interceptors to access a card play as it's happening
	var action_data: Array[Dictionary] = [{Scripts.ACTION_CARD_PLAY: {}}]
	var generated_action: BaseAction = ActionGenerator.create_actions(player, card_play_request, [], action_data, null)[0]
	var _action_interceptor_processors: Array[ActionInterceptorProcessor] = generated_action._intercept_action([])
	
	# find out where the card came from
	var card_location: int = card_play_request.card_data.get_card_deck_location()
	
	# remove card from hand/discard/draw/exhaust
	move_card_to_limbo(card_play_request.card_data)
	
	# notify that the card play is beginning
	# NOTE: If you want certain things to happen right before a card play at this moment (like a status effect),
	# you can listen for the card_play_started and then add to the current action queue. Adding to the stack
	# however will not make the actions happen immediately before the action takes place and ordering will
	# not always be consistent.
	Signals.card_play_started.emit(card_play_request)
	# block in case card play starting triggers any effects
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	
	# get targets
	var targets: Array[BaseCombatant] = [card_play_request.selected_target]
	
	### generate and perform play card actions
	# generate the card actions
	var card_play_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, targets, card_play_request.card_data.card_play_actions, null)
	# generate a special action which signifies the end of the card play, to be done after all the other card actions
	var card_played_finished_action: Array[BaseAction] = [ActionGenerator.generate_card_play_finished(card_play_request)]
	
	ActionHandler.add_actions(card_played_finished_action + card_play_actions)
	
	# update the hand while the actions are processing
	tween_hand()
	update_hand_card_display()
	
	# block until the card and any subsequent effects are completely finished
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	
	# determine where to move card to after being played
	if CardData.NON_REUSABLE_CARD_TYPES.has(card_play_request.card_data.card_type):
		pass
	else:
		# transfer card from hand to discard/exhaust pile
		if card_play_request.card_data.card_exhausts:
			# exhaust pile
			Global.player_data.player_exhaust.append(card_play_request.card_data)
			# card cannot be considered exhausted twice in a duplicate play
			if not card_play_request.is_duplicate_play:
				# cannot exhaust a card already from exhaust pile
				if card_location != CardPlayRequest.CARD_PLAY_DESTINATIONS.EXHAUST:
					Signals.card_exhausted.emit(card_play_request.card_data)
		else:
			# discard pile
			Global.player_data.player_discard.append(card_play_request.card_data)
	
	combat.update_combat_display()

### Card Play Queue

#func add_card_to_play_queue(card_data: CardData, selected_target: BaseCombatant, require_energy: bool = true, is_duplicate_play: bool = false, front_of_queue: bool = false) -> void:
func add_card_to_play_queue(card_play_request: CardPlayRequest, require_energy: bool = true, front_of_queue: bool = false) -> void:
	# queues up a card to be played and automatically begins playing cards if none in queue
	# card play will cost energy if desired with require_energy. Manually playing cards always requres energy, while other sources may not
	# cards can be made to play next with front_of_queue 
	
	var card_data: CardData = card_play_request.card_data
	# insufficient energy, don't add to queue
	if require_energy:
		if card_data.get_card_energy_cost() > Global.player_data.player_energy:
			return
	
	card_play_queue.append(card_play_request)
	
	if require_energy and not card_play_request.is_duplicate_play:
		# reserve energy
		var energy_cost: int = card_data.get_card_energy_cost()
		
		# variable cost cards consume all energy
		if card_data.card_energy_cost_is_variable:
			energy_cost = Global.player_data.player_energy
			# variable cost cards can have an upper bound to energy input
			if card_data.card_energy_cost_variable_upper_bound >= 0:
				energy_cost = min(energy_cost, card_data.card_energy_cost_variable_upper_bound)
		
		card_play_request.refundable_energy = energy_cost
		card_play_request.input_energy = energy_cost
		card_play_queue_reserved_energy_total += energy_cost
		
		# energy cost
		Global.player_data.player_energy -= energy_cost
		combat.update_combat_display()
	else:
		# card doesn't require energy, reserve -1 energy in energy queue
		card_play_request.refundable_energy = CARD_NO_ENERGY_COST
		
		if card_data.card_energy_cost_is_variable:
			if card_play_request.is_duplicate_play:
				card_play_request.input_energy = Global.player_data.player_energy
		else:
			card_play_request.input_energy = 0
	
	# flip the card play to the front of the queue if desired
	if front_of_queue:
		card_play_queue.push_front(card_play_queue.pop_back())
	
	# automatically play the card if the current queue and actions performed are empty
	if (not ActionHandler.actions_being_performed) and (not cards_being_played):
		_perform_card_plays()

func _perform_card_plays() -> void:	
	# plays all cards in the card queue
	cards_being_played = true
	while len(card_play_queue) > 0:
		# no more enemies
		if len(get_tree().get_nodes_in_group("enemies")) == 0:
			clear_card_queue()
			break
		
		# pop the next card from the queue and play it
		var card_play_request: CardPlayRequest = card_play_queue.pop_front()
		var card_data: CardData = card_play_request.card_data
		var card_energy_cost = card_play_request.refundable_energy
		var card_target: BaseCombatant = card_play_request.selected_target
		card_play_queue_reserved_energy_total -= max(card_energy_cost, 0)
		
		# exit card queue if card somehow went up in energy cost
		if card_energy_cost != CARD_NO_ENERGY_COST:
			if card_data.get_card_energy_cost() > card_energy_cost:
				# card energy cost changed for the worse, refund energy
				card_play_queue.push_front(card_play_request)
				refund_card_queue()
				break
		
		# exit card queue if target no longer exists
		if card_target != null and not card_target.is_alive():
			card_play_queue.push_front(card_play_request)
			refund_card_queue()
			break
		
		_play_card(card_play_request)
		if ActionHandler.actions_being_performed:
			await ActionHandler.actions_ended
		
		await get_tree().create_timer(0.2).timeout
	
	cards_being_played = false

func _perform_card_right_click_actions(card: Card) -> void:
	# locks further card actions and performs a right click on a card
	if len(card.card_data.card_right_click_actions) > 0:
		performing_card_right_click = true # locks further card actions
		# generate fake card request
		var card_play_request: CardPlayRequest = CardPlayRequest.new()	# generate fake request
		card_play_request.card_data = card.card_data
		card_play_request.selected_target = null
		# generate card actions
		var card_right_click_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card.card_data.card_right_click_actions, null)
		ActionHandler.add_actions(card_right_click_actions)
		
		if ActionHandler.actions_being_performed:
			await ActionHandler.actions_ended
			
		performing_card_right_click = false

func clear_card_queue() -> void:
	card_play_queue.clear()
	card_play_queue_reserved_energy_total = 0
	cards_being_played = false

func refund_card_queue():
	# clears out the card queue, refunding all the energy in it
	#print("refunding at " + str(Global.player_data.player_energy))
	for card_play_request in card_play_queue:
		Global.player_data.player_energy += card_play_request.refundable_energy
		#print(str(card_play_request.refundable_energy) + " refunded")
	#print("total " + str(Global.player_data.player_energy))
	clear_card_queue()
	Signals.card_queue_refunded.emit()

func _on_card_played(card_play_request: CardPlayRequest):
	# reset card play cost
	if card_play_request.card_data.card_energy_cost_until_played > -1:
		card_play_request.card_data.set_card_energy_cost_until_played(-1)

func _on_card_play_requested(card_play_request: CardPlayRequest, require_energy: bool = true, front_of_queue: bool = false):
	add_card_to_play_queue(card_play_request, require_energy, front_of_queue)


### Card Picking

func update_card_pick_ui():
	# update ui
	confirm_pick_button.disabled = true
	if current_card_pick_action != null:
		confirm_pick_button.disabled = not current_card_pick_action.are_enough_cards_picked()
	
		card_picking_label.text = current_card_pick_action.get_card_pick_text() 
	

func attempt_pick_card(card: Card):
	# user selected a card while a pick request is made
	# the card will be picked or unpicked
	if current_card_pick_action != null:
		# unpick card
		if current_card_pick_action.picked_cards.has(card.card_data):
			current_card_pick_action.picked_cards.erase(card.card_data) # remove from picked cards
		# pick card
		else:
			# card can be picked
			if current_card_pick_action.is_card_pickable(card.card_data):
				current_card_pick_action.picked_cards.append(card.card_data)	# add to picked cards
		
		update_card_pick_ui()
		tween_hand()

func unpick_card(card: Card):
	if current_card_pick_action != null:
		current_card_pick_action.picked_cards.erase(card)

func _on_confirm_pick_button_up():
	# user has confirmed the selected cards
	Signals.card_pick_confirmed.emit()
	tween_hand()
	
func _on_card_pick_requested(card_selection_action: ActionBasePickCards):
	if card_selection_action.get_card_pick_type() == ActionBasePickCards.CARD_PICK_TYPES.HAND:
		card_picking.visible = true
		current_card_pick_action = card_selection_action
		update_card_pick_ui()
		set_hand_invalid_card_pick_visibility(false)

func _on_card_pick_confirmed():
	card_picking.visible = false
	current_card_pick_action = null
	set_hand_invalid_card_pick_visibility(true)

func set_hand_invalid_card_pick_visibility(invalid_cards_visible: bool) -> void:
	# used for hand card picking. All invalid cards will be temporarily hidden based on the requested action
	for card: Card in card_data_to_hand_card.values():
		card.visible = true
		if current_card_pick_action != null:
			if not current_card_pick_action.is_card_pickable(card.card_data):
				card.visible = invalid_cards_visible

### Card Management

func move_card_to_limbo(card_data: CardData) -> void:
	# removes a card from everything in player's deck and hand
	# useful for resetting a card to move it into one place
	Global.player_data.player_draw.erase(card_data)
	Global.player_data.player_discard.erase(card_data)
	Global.player_data.player_exhaust.erase(card_data)
	Global.player_data.player_hand.erase(card_data)
	card_data_to_hand_card.erase(card_data)

func create_cards(cards: Array[CardData]) -> Array[Card]:
	var created_cards: Array[Card] = []

	for card_data in cards:
		var card: Card = Scenes.CARD.instantiate()
		add_child(card)
		card.init(card_data, 0, true, true)
		
		created_cards.append(card)
	
	return created_cards

func discard_hand(is_manual_discard: bool = false):
	discard_cards(get_player_hand(), is_manual_discard)

func _on_card_draw_requested(number_of_cards: int, hand_card_count_max: int) -> void:
	draw_cards(number_of_cards)

## Can take a hand_card_count_max which restricts cards beyond the hand size limit.
func draw_cards(card_number: int, hand_card_count_max: int = PlayerData.PLAYER_DEFAULT_HAND_CARD_COUNT_MAX) -> void:
	var drawn_cards: Array[Card] = []
	
	for i in card_number:
		
		# hand full, stop drawing and move drawn card to discard
		if len(Global.player_data.player_hand) >= hand_card_count_max:
			Signals.card_hand_limit_reached.emit()
			
			break
		# check if enough cards to draw
		if len(Global.player_data.player_draw) == 0:
			# try to reshuffle
			if len(Global.player_data.player_discard) == 0:
				# no cards to shuffle into draw
				break
			else:
				shuffle_draw(true, true)
		
		# draw
		var card_data: CardData = Global.player_data.player_draw.pop_back()
		Global.player_data.player_hand.append(card_data)
		
		var card: Card = create_cards([card_data])[0]
		card_data_to_hand_card[card.card_data] = card
		
		drawn_cards.append(card)
		
		# bind signals
		card.card_hovered.connect(_on_card_hovered)
		card.card_unhovered.connect(_on_card_unhovered)
		card.card_selected.connect(_on_card_selected)
		card.card_right_clicked.connect(_on_card_right_clicked)
		
		# generate fake card request
		var card_play_request: CardPlayRequest = CardPlayRequest.new()	# generate fake request
		card_play_request.card_data = card_data
		card_play_request.selected_target = null
		
		# perform draw actions
		var card_play_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card_data.card_draw_actions, null)
		ActionHandler.add_actions(card_play_actions)
		
		Signals.card_drawn.emit(card_data)
		
	# rerender hand
	tween_hand()

func _on_card_add_to_draw_requested(cards: Array[CardData], card_destination: int) -> void:
	add_cards_to_draw(cards, card_destination)
	
func add_cards_to_draw(cards: Array[CardData], card_destination: int = CardPlayRequest.CARD_PLAY_DESTINATIONS.DRAW_TOP) -> void:
	# adds cards directly to draw pile
	for card_data: CardData in cards.duplicate():
		move_card_to_limbo(card_data)
		match card_destination:
			CardPlayRequest.CARD_PLAY_DESTINATIONS.DRAW_BOTTOM:
				# put card at bottom of draw pile
				Global.player_data.player_draw.push_front(card_data)
				Signals.card_added_to_draw.emit(card_data)
				continue
			CardPlayRequest.CARD_PLAY_DESTINATIONS.DRAW_INSERT:
				# randomly insert the card in the draw pile
				var rng_pile_insert: RandomNumberGenerator = Global.player_data.get_player_rng("rng_pile_insert")
				var card_insert_index: int = rng_pile_insert.randi_range(0, len(Global.player_data.player_draw))
				Global.player_data.player_draw.insert(card_insert_index, card_data)
				Signals.card_added_to_draw.emit(card_data)
				continue
			_, CardPlayRequest.CARD_PLAY_DESTINATIONS.DRAW_TOP:
				# put card at top of draw pile
				Global.player_data.player_draw.push_back(card_data)
				Signals.card_added_to_draw.emit(card_data)
				continue
	
	tween_hand()
	update_hand_card_display()

func _on_card_add_to_hand_requested(cards: Array[CardData], hand_card_count_max: int) -> void:
	add_cards_to_hand(cards, hand_card_count_max)
	
## Adds cards directly to hand, discarding any additional ones if it's too full.
## Does not count as a draw.
## Can take a hand_card_count_max which restricts cards beyond the hand size limit.
func add_cards_to_hand(cards: Array[CardData], hand_card_count_max: int = PlayerData.PLAYER_DEFAULT_HAND_CARD_COUNT_MAX) -> void:
	var discarded_cards: Array[CardData] = []
	var added_cards: Array[CardData] = []
	var player_hand: Array[CardData] = get_player_hand()
	for card_data: CardData in cards.duplicate():
		if not player_hand.has(card_data):
			if len(Global.player_data.player_hand) < hand_card_count_max:
				move_card_to_limbo(card_data)
				var card: Card = create_cards([card_data])[0]
				
				card_data_to_hand_card[card.card_data] = card
				Global.player_data.player_hand.append(card_data)
				
				added_cards.append(card_data)
				
				# bind signals
				card.card_hovered.connect(_on_card_hovered)
				card.card_unhovered.connect(_on_card_unhovered)
				card.card_selected.connect(_on_card_selected)
				card.card_right_clicked.connect(_on_card_right_clicked)
			else:
				discarded_cards.append(card_data)
	
	if len(discarded_cards) > 0:
		Signals.card_hand_limit_reached.emit()
		discard_cards(discarded_cards, false)
			
	tween_hand()

func _on_card_discard_requested(cards: Array[CardData], is_manual_discard: bool = false) -> void:
	discard_cards(cards, is_manual_discard)

func _on_card_exhaust_requested(cards: Array[CardData]) -> void:
	exhaust_cards(cards)

func _on_card_banish_requested(cards: Array[CardData], in_limbo: bool) -> void:
	banish_cards(cards, in_limbo)

func _on_card_retain_requested(cards: Array[CardData]) -> void:
	for card in cards:
		if not cards_retained_this_turn.has(card):
			cards_retained_this_turn.append(card)

func _on_reshuffle_requested(shuffle_discard_into_draw):
	shuffle_draw(shuffle_discard_into_draw, true)

func discard_cards(cards: Array[CardData], is_manual_discard: bool = false) -> void:
	# manual discard is player selected cards
	for card_data in cards.duplicate():
		# transfer card
		move_card_to_limbo(card_data)
		Global.player_data.player_discard.append(card_data)
		
		# perform discard actions
		if is_manual_discard:
			# generate fake card play request
			var card_play_request: CardPlayRequest = CardPlayRequest.new()
			card_play_request.card_data = card_data
			card_play_request.selected_target = null
			
			var card_play_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card_data.card_discard_actions, null)
			ActionHandler.add_actions(card_play_actions)
		
		Signals.card_discarded.emit(card_data, is_manual_discard)
	
	# rerender hand
	tween_hand()

func exhaust_cards(cards: Array[CardData]) -> void:
	for card_data in cards.duplicate():
		move_card_to_limbo(card_data)
		Global.player_data.player_exhaust.append(card_data)
		
		# generate fake card play request
		var card_play_request: CardPlayRequest = CardPlayRequest.new()
		card_play_request.card_data = card_data
		card_play_request.selected_target = null
		# perform exhaust actions
		var card_exhaust_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card_data.card_exhaust_actions, null)
		ActionHandler.add_actions(card_exhaust_actions)
		
		Signals.card_exhausted.emit(card_data)
	
	# rerender hand
	tween_hand()

func banish_cards(cards: Array[CardData], in_limbo: bool = false) -> void:
	# completely removes a card from play
	for card_data in cards.duplicate():
		move_card_to_limbo(card_data)
		Signals.card_banished.emit(card_data, in_limbo)
	
	# rerender hand
	tween_hand()

func shuffle_draw(shuffle_discard_into_draw: bool = true, is_reshuffle: bool = true) -> void:
	
	# if you want to shuffle your discard into the draw, or simply randomize draw
	if shuffle_discard_into_draw:
		Global.player_data.player_draw += Global.player_data.player_discard
		Global.player_data.player_discard = []
	
	var shuffle_rng: RandomNumberGenerator = Global.player_data.get_player_rng("rng_shuffle")
	
	# randomize the draw pile
	if is_reshuffle:
		# do a basic reshuffle ignoring card ordering
		Global.player_data.player_draw = Random.shuffle_array(shuffle_rng, Global.player_data.player_draw)
	else:
		### put cards into priority buckets, shuffle the individual buckets, then merge them
		var shuffled_draw: Array[CardData] = []
		var shuffle_priority_to_cards: Dictionary = {}
		# create buckets
		for card_data in Global.player_data.player_draw:
			var priority: int = card_data.card_first_shuffle_priority
			var card_bucket: Array[CardData] = []
			if shuffle_priority_to_cards.has(priority):
				card_bucket = shuffle_priority_to_cards[priority]
			card_bucket.append(card_data)
			shuffle_priority_to_cards[priority] = card_bucket
		# get sorted buckets
		var card_priorities: Array = shuffle_priority_to_cards.keys().duplicate()
		card_priorities.sort()
		# shuffle buckets and add them to draw
		for priority in card_priorities:
			var bucket_cards: Array[CardData] = shuffle_priority_to_cards[priority]
			bucket_cards = Random.shuffle_array(shuffle_rng, bucket_cards)
			shuffled_draw += bucket_cards
		# overwrite draw pile with bucket shuffled cards
		Global.player_data.player_draw = shuffled_draw
	
	# deck shuffle on first turn not counted as a deck reshuffle event
	Signals.card_deck_shuffled.emit(is_reshuffle)

func reset_deck() -> void:
	# resets the deck to be used for the start of combat
	for child in get_children():
		child.queue_free()
	card_data_to_hand_card.clear()
	
	var combat_deck: Array[CardData] = Global.player_data.generate_combat_deck()
	Global.player_data.player_draw = combat_deck	# copy deck into player's draw pile
	Global.player_data.player_discard = []
	Global.player_data.player_exhaust = []
	Global.player_data.player_discard = []
	Global.player_data.player_hand = []
	
	shuffle_draw(true, false)

func _on_disable_hand_requested(_disabled: bool = true):
	hand_disabled = _disabled
	if hand_disabled:
		current_selected_card = null
		_unprompt_target()

### Combat/Turns

func perform_end_of_turn_hand_actions() -> void:
	# exhaust ethereal cards, and perform specific end of turn card actions
	
	# reset cards with modified turn energy
	for card in cards_with_modified_turn_energy:
		if card.card_energy_cost_until_turn > -1:
			card.set_card_energy_cost_until_turn(-1)
	cards_with_modified_turn_energy.clear()
	
	# get cards with end of turn actions
	var end_of_turn_cards: Array[CardData] = []
	for card_data in get_player_hand():
		if len(card_data.card_end_of_turn_actions) > 0:
			end_of_turn_cards.append(card_data)
	
	# perform the end of turn actions
	for card_data in end_of_turn_cards:
		var card_play_request: CardPlayRequest = CardPlayRequest.new()
		card_play_request.card_data = card_data
		card_play_request.selected_target = null
		
		var card_end_of_turn_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card_data.card_end_of_turn_actions, null)
		ActionHandler.add_actions(card_end_of_turn_actions)
	
	# get all ethereal cards and exhaust them
	var ethereal_cards: Array[CardData] = []
	for card_data in get_player_hand():
		if card_data.card_is_ethereal:
			ethereal_cards.append(card_data)
	
	if len(ethereal_cards) > 0:
		exhaust_cards(ethereal_cards)
		
		# wait for tweens to finish
		await Global.get_tree().create_timer(CARD_TWEEN_TIME).timeout
		
	# wait for actions
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	
	# retain/discard cards
	var discarded_cards: Array[CardData] = []
	for card_data in get_player_hand():
		# check if card flagged for retain
		var card_is_retained: bool = card_data.card_is_retained or cards_retained_this_turn.has(card_data)
		
		if card_is_retained:
			# generate fake card play request
			var card_play_request: CardPlayRequest = CardPlayRequest.new()
			card_play_request.card_data = card_data
			card_play_request.selected_target = null
			# perform retain actions
			var card_retain_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card_data.card_retain_actions, null)
			ActionHandler.add_actions(card_retain_actions)
		
			Signals.card_retained.emit(card_data)
		else:
			discarded_cards.append(card_data)
	
	cards_retained_this_turn.clear()
	
	if len(discarded_cards) > 0:
		discard_cards(discarded_cards, false)
		
		# wait for tween/card actions to finish
		await Global.get_tree().create_timer(CARD_TWEEN_TIME).timeout
	
	# wait for actions
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended

func _on_combat_started(_event_id: String):
	_unprompt_target()
	cards_retained_this_turn.clear()
	cards_with_modified_turn_energy.clear()
	clear_card_queue()
	reset_deck()
	
func _on_combat_ended():
	cards_retained_this_turn.clear()
	cards_with_modified_turn_energy.clear()
	clear_card_queue()
	
	_unprompt_target()
	
	# remove cards in hand
	for child in get_children():
		child.queue_free()
	card_data_to_hand_card.clear()

func _on_run_ended():
	cards_retained_this_turn.clear()
	cards_with_modified_turn_energy.clear()
	clear_card_queue()
	
	# remove cards in hand
	for child in get_children():
		child.queue_free()
	card_data_to_hand_card.clear()

func _on_card_turn_energy_changed(card_data: CardData):
	# track cards with turn energy shadowing
	if card_data.card_energy_cost_until_turn > -1:
		if not cards_with_modified_turn_energy.has(card_data):
			cards_with_modified_turn_energy.append(card_data)

func _on_player_killed(_player: Player):
	discard_hand(false)

### Helpers

func get_player_hand() -> Array[CardData]:
	# helper method for getting player hand
	return Global.player_data.player_hand

func get_player_hand_cards() -> Array[Card]:
	# gets ui cards in player hand
	var hand_cards: Array[Card] = []
	for card in card_data_to_hand_card.values():
		if is_instance_valid(card):
			hand_cards.append(card)
	return hand_cards

func update_hand_card_display() -> void:
	# forces updates of all cards in player's hand
	for cd in card_data_to_hand_card.values():
		var card: Card = cd # typecast iterator
		card.update_card_display()
