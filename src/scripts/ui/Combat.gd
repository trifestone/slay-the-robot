# maintains combat UI
extends Control

@onready var money_label: Label = $%MoneyLabel
@onready var health_label: Label = $%HealthLabel

@onready var energy_count: Label = $Energy/EnergyCount
@onready var energy: TextureButton = $Energy
@onready var draw_count: Label = $DrawPile/DrawCount
@onready var discard_count: Label = $DiscardPile/DiscardCount
@onready var exhaust_count: Label = $ExhaustPile/ExhaustCount

@onready var deck_button: TextureButton = $DeckButton
@onready var draw_pile_button: TextureButton = $DrawPile
@onready var discard_pile_button: TextureButton = $DiscardPile
@onready var exhaust_pile_button: TextureButton = $ExhaustPile

@onready var card_selection_overlay = $%CardSelectionOverlay

@onready var combat_animation_player: AnimationPlayer = $CombatAnimation
@onready var enemy_container = $EnemyContainer

@onready var player = $Player
@onready var hand = $Hand
@onready var chest = $Chest
@onready var shop = $Shop

@onready var background_button: TextureButton = %BackgroundButton

@onready var end_turn_button: Button = $EndTurnButton
var end_turn_object: CombatEndTurn = null

func _ready():
	Signals.player_money_changed.connect(_on_player_money_changed)
	Signals.player_health_changed.connect(_on_player_health_changed)
	
	Signals.enemy_killed.connect(_on_enemy_killed)
	Signals.enemy_death_animation_finished.connect(_on_enemy_death_animation_finished)
	
	Signals.combat_started.connect(_on_combat_started)
	Signals.combat_ended.connect(_on_combat_ended)
	
	Signals.player_turn_started.connect(_on_player_turn_started)
	Signals.player_turn_ended.connect(_on_player_turn_ended)
	Signals.enemy_turn_ended.connect(_on_enemy_turn_ended)
	Signals.enemy_turn_started.connect(_on_enemy_turn_started)
	
	Signals.end_turn_requested.connect(_on_end_turn_requested)
	
	end_turn_button.button_up.connect(_on_end_turn_button_up)
	
	update_combat_display()
	player.update_player_display(Global.player_data)
	
	# pile buttons
	deck_button.button_up.connect(_on_deck_button_up)
	draw_pile_button.button_up.connect(_on_draw_pile_button_up)
	discard_pile_button.button_up.connect(_on_discard_pile_button_up)
	exhaust_pile_button.button_up.connect(_on_exhaust_pile_button_up)
	
	# updating pile counts when cards do things
	Signals.card_played.connect(_on_card_played)	# player is playing card
	Signals.card_drawn.connect(_on_card_drawn)
	Signals.card_deck_shuffled.connect(_on_card_deck_shuffled)
	Signals.card_discarded.connect(_on_card_discarded)
	Signals.card_exhausted.connect(_on_card_exhausted)
	
	Signals.energy_added.connect(_on_energy_added)
	Signals.card_queue_refunded.connect(_on_card_queue_refunded)
	
	Signals.run_started.connect(_on_run_started)
	Signals.run_ended.connect(_on_run_ended)
	
	Signals.map_location_selected.connect(_on_map_location_selected)

func _on_map_location_selected(location_data: LocationData):
	# determine what to do when the player visits a new location
	var location_type: int = location_data.location_type
	
	chest.visible = false
	shop.visible = false
	
	set_combat_display_visibility(false)
	
	match location_type:
		LocationData.LOCATION_TYPES.COMBAT, LocationData.LOCATION_TYPES.MINIBOSS, LocationData.LOCATION_TYPES.BOSS:
			ActionGenerator.generate_combat_start("") # emit empty event to get location's combat event
		LocationData.LOCATION_TYPES.TREASURE:
			chest.visible = true
		LocationData.LOCATION_TYPES.SHOP:
			shop.visible = true
	
	_update_background()

func update_combat_display():
	energy_count.text = str(Global.player_data.player_energy) + "/" + str(Global.player_data.player_energy_max)
	draw_count.text = str(len(Global.player_data.player_draw))
	discard_count.text = str(len(Global.player_data.player_discard))
	exhaust_count.text = str(len(Global.player_data.player_exhaust))
	_on_player_health_changed()
	_on_player_money_changed()

func _update_background() -> void:
	# set the background if possible
	var background_texture_path: String = ""
	
	var act_id: String = Global.player_data.player_act_id
	var act_data: ActData = Global.get_act_data(act_id)
	var location_data: LocationData = Global.get_player_location_data()
	
	# act background
	if act_data.act_background_texture_path != "":
		background_texture_path = act_data.act_background_texture_path
	# location background
	if location_data.location_background_texture_path != "":
		background_texture_path = location_data.location_background_texture_path
	# event background
	var location_event_object_id: String = location_data.get_location_event_object_id()
	if location_event_object_id != "":
		var event_data: EventData = Global.get_event_data(location_event_object_id)
		if event_data.event_background_texture_path != "":
			background_texture_path = event_data.event_background_texture_path
	
	if background_texture_path != "":
		background_button.texture_normal = FileLoader.load_texture(background_texture_path)
	

func set_combat_display_visibility(display_visibility: bool) -> void:
	energy.visible = display_visibility
	draw_pile_button.visible = display_visibility
	discard_pile_button.visible = display_visibility
	exhaust_pile_button.visible = display_visibility
	end_turn_button.visible = display_visibility

func _on_card_played(_card_play_request: CardPlayRequest):
	update_combat_display()

func _on_card_drawn(_card_data: CardData):
	update_combat_display()

func _on_card_deck_shuffled(_is_reshuffle: bool):
	update_combat_display()

func _on_card_discarded(_card_data: CardData, _is_manual_discard: bool):
	update_combat_display()

func _on_card_exhausted(_card_data: CardData):
	update_combat_display()

func _on_energy_added(_energy_amount: int):
	update_combat_display()

func _on_card_queue_refunded():
	update_combat_display()

func _on_player_money_changed():
	money_label.text = "$%s" % Global.player_data.player_money

func _on_player_health_changed():
	health_label.text = "%s / %s" % [Global.player_data.player_health, Global.player_data.player_health_max]

### Deck Buttons

func _on_deck_button_up():
	card_selection_overlay.view_deck()
func _on_draw_pile_button_up():
	card_selection_overlay.view_draw_pile()
func _on_discard_pile_button_up():
	card_selection_overlay.view_discard()
func _on_exhaust_pile_button_up():
	card_selection_overlay.view_exhaust()

### Turn Handling

func _on_enemy_killed(enemy: Enemy):
	var generated_actions: Array[BaseAction] = ActionGenerator.create_actions(enemy, null, [], enemy.enemy_data.enemy_actions_on_death, null)
	ActionHandler.add_actions(generated_actions)
	
	
func _on_enemy_death_animation_finished(_enemy: Enemy):
	# determine if all non minion enemies killed and end combat
	var enemies: Array[Enemy] = []
	enemies.assign(get_tree().get_nodes_in_group("enemies"))
	
	var non_minion_enemies_remain: bool = true
	for enemy in enemies:
		if not enemy.enemy_data.enemy_is_minion:
			non_minion_enemies_remain = false
	
	if non_minion_enemies_remain:
		# wait for actions to finish and end combat
		if ActionHandler.actions_being_performed:
			await ActionHandler.actions_ended
		Signals.combat_ended.emit()

func _on_combat_started(event_id: String):
	var current_event: EventData = null
	if event_id == "":
		# if no event is provided, it will be derived from the location
		var current_location: LocationData = Global.get_player_location_data()
		current_event = Global.get_player_event_data()
		current_location.location_visited = true
	else:
		current_event = Global.get_event_data(event_id)
	
	enemy_container.populate_enemies(current_event)
	start_turn_animation()
	
	Global.player_data.player_energy = Global.player_data.player_energy_max
	set_combat_display_visibility(true)
	update_combat_display()
	
func _on_combat_ended():
	set_combat_display_visibility(false)
	

func perform_enemy_turn():
	# generates enemy actions and performs them in order
	var enemies: Array = get_tree().get_nodes_in_group("enemies")
	if len(enemies) == 0:
		Signals.combat_ended.emit()
		return
	
	# Enemy Turn
	for e in enemies:
		# get enemy standard attack data
		var enemy: Enemy = e	# typecast iterator
		
		
		### perform enemy start of turn statuses
		if enemy.is_alive():
			enemy.perform_status_effect_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.ENEMY_START_TURN)
			if ActionHandler.actions_being_performed:
				await ActionHandler.actions_ended 
		
		### perform intent
		# NOTE: remember these go in reverse order on the stack
		if enemy.is_alive():
			# add custom actions
			var enemy_actions_data: Array[Dictionary] = []
			enemy_actions_data.assign(enemy.enemy_data.get_current_attack_custom_actions())
			
			# add attacks
			var enemy_attack: Array = enemy.enemy_data.get_current_attack_damages()
			if enemy_attack[1] > 0:
				enemy_actions_data.append(
				{
				Scripts.ACTION_ATTACK_GENERATOR: {"damage": enemy_attack[0], "number_of_attacks": enemy_attack[1], "time_delay": EnemyData.ENEMY_ATTACK_DELAY}
				}
				)
			
			# add block
			var enemy_block: int = enemy.enemy_data.get_current_attack_block()
			if enemy_block > 0:
				enemy_actions_data.append(
					{
					Scripts.ACTION_BLOCK: {
						"block": enemy_block,
						"target_override": BaseAction.TARGET_OVERRIDES.PARENT,
						"time_delay": 0.0,
						}
					}
			)
			
			# add reset block action
			enemy_actions_data.append(
			{
			Scripts.ACTION_RESET_BLOCK:  {
				"target_override": BaseAction.TARGET_OVERRIDES.PARENT,
				"time_delay": 0.0
				}
			}
			)
			
			# perform them and wait
			var enemy_attack_actions: Array = ActionGenerator.create_actions(enemy, null, [player], enemy_actions_data, null)
			ActionHandler.add_actions(enemy_attack_actions)
			if ActionHandler.actions_being_performed:
				await ActionHandler.actions_ended
		
		### Perform enemy end of turn statuses
		if enemy.is_alive():
			enemy.perform_status_effect_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.ENEMY_END_TURN)
			if ActionHandler.actions_being_performed:
				await ActionHandler.actions_ended 
		
		# if player is dead stop
		if Global.player_data.player_health <= 0:
			return
	
	# all enemies dead
	enemies = get_tree().get_nodes_in_group("enemies")
	if len(enemies) == 0:
		Signals.combat_ended.emit()
		return
	
	Signals.enemy_turn_ended.emit()

	
func _on_player_turn_started():
	# prevent player from playing cards manually
	hand.hand_disabled = true
	
	# first turn actions
	if Global.get_combat_stats().turn_count == 1:
		# location initial actions
		var location_data: LocationData = Global.get_player_location_data()
		assert(location_data != null)
		if location_data != null:
			var card_play_request: CardPlayRequest = CardPlayRequest.new()	# generate fake request
			card_play_request.card_data = null
			card_play_request.selected_target = null
			
			# perform location initial actions
			var location_initial_combat_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], location_data.location_initial_combat_actions, null)
			ActionHandler.add_actions(location_initial_combat_actions)
		
			# wait for first turn actions
			if ActionHandler.actions_being_performed:
				await ActionHandler.actions_ended
			
			# perform event initial actions
			var event_data: EventData = Global.get_player_event_data()
			var event_initial_combat_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], event_data.event_initial_combat_actions, null)
			ActionHandler.add_actions(event_initial_combat_actions)
			
			# wait for first turn actions
			if ActionHandler.actions_being_performed:
				await ActionHandler.actions_ended
			
		
		# combat start card actions
		for card_data: CardData in Global.player_data.player_draw:
			var card_play_request: CardPlayRequest = CardPlayRequest.new()	# generate fake request
			card_play_request.card_data = card_data
			card_play_request.selected_target = null
			
			# perform initial actions
			var card_play_actions: Array[BaseAction] = ActionGenerator.create_actions(player, card_play_request, [], card_data.card_initial_combat_actions, null)
			ActionHandler.add_actions(card_play_actions)
	
		# wait for first turn actions
		if ActionHandler.actions_being_performed:
			await ActionHandler.actions_ended
	
	# perform pre draw actions
	player.update_incoming_damage_amount(true)
	player.generate_reset_block_action()
	player.perform_status_effect_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.POST_DRAW_PLAYER_START_TURN)
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	
	# draw cards
	ActionGenerator.generate_start_of_turn_draw_actions()
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	
	# perform post draw actions
	player.perform_status_effect_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PRE_DRAW_PLAYER_START_TURN)
	
	# unlock and update hand
	hand.hand_disabled = false
	hand.update_hand_card_display()

func _on_player_turn_ended():
	# prevent player from playing cards
	hand.hand_disabled = true
	# discard non retained cards and perform card actions
	hand.perform_end_of_turn_hand_actions()
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	
	# perform all end of turn actions and await
	player.perform_status_effect_actions(StatusEffectData.STATUS_EFFECT_PROCESS_TIMES.PLAYER_END_TURN)
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	

func _on_player_start_turn_animation_finished():
	# called from animation player
	start_turn()

func _on_player_end_turn_animation_finished():
	# called from animation player
	Signals.player_turn_ended.emit()
	
	# wait for all end of turn actions to process
	if ActionHandler.actions_being_performed:
		await ActionHandler.actions_ended
	
	# start enemy turn if they're alive
	if len(get_tree().get_nodes_in_group("enemies")) > 0:
		Signals.enemy_turn_started.emit()

func _on_enemy_turn_started():
	perform_enemy_turn()
	
func _on_enemy_turn_ended():
	start_turn_animation()
	
func _on_end_turn_button_up():
	queue_end_turn(CombatEndTurn.END_TURN_QUEUE_IMMEDIACY.WAIT_FOR_ALL_CARD_PLAYS)

func _on_end_turn_requested(immediacy: int):
	queue_end_turn(immediacy)

func queue_end_turn(immediacy: int = CombatEndTurn.END_TURN_QUEUE_IMMEDIACY.WAIT_FOR_ALL_CARD_PLAYS):
	# queues up an end turn, using async objects with priority to determine how to handle it
	if end_turn_object == null:
		end_turn_object = CombatEndTurn.new(self, %Hand, immediacy)
		end_turn_object.wait()
		end_turn_button.disabled = true
	elif immediacy > end_turn_object.end_turn_queue_value:
		# higher priority end turn, replace the old with a newer one
		end_turn_object.disable()	# stop the old one working
		end_turn_object = CombatEndTurn.new(self, %Hand, immediacy)
		end_turn_object.wait()

func _reset_turn_end_queue() -> void:
	if end_turn_object != null:
		end_turn_object.disable()
		end_turn_object = null

func _on_run_started():
	visible = true
	_on_player_health_changed()
	_on_player_money_changed()
	
func _on_run_ended():
	visible = false
	_reset_turn_end_queue()

func start_combat() -> void:
	_reset_turn_end_queue()

func end_combat() -> void:
	_reset_turn_end_queue()

func end_turn():
	pass

func start_turn():
	# called from animation player
	_reset_turn_end_queue()
	Global.player_data.player_energy = Global.player_data.player_energy_max
	update_combat_display()
	Signals.player_turn_started.emit()

func end_turn_animation() -> void:
	_reset_turn_end_queue()
	combat_animation_player.play("end_turn")
	
func start_turn_animation() -> void:
	combat_animation_player.play("start_turn")
