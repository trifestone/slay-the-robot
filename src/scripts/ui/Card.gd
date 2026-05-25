# UI element representing a CardData
extends Control
class_name Card

var card_data: CardData = null
var card_listeners: Array[BaseCardListener] = []

const CARDS_RERENDER_LAZILY: bool = true # throttles card display generation to next frame
var _card_is_rerendering: bool = false

const CARD_TEXT_IMAGE_SIZE: int = 16	# images in card descriptions will be set to this size
const ENERGY_ICON_KEYWORD: String = "[energy_icon]"	# tells description to display an energy icon in place

@onready var card_button: Button = %CardButton

@onready var pivot: Node2D = $Pivot

@onready var card_texture = %CardTexture
@onready var card_name: RichLabelAutoSizer = %CardName
@onready var card_type: Label = %CardType
@onready var card_description: RichLabelAutoSizer = %CardDescription
@onready var card_energy_cost: Label = %EnergyCost
@onready var card_color: ColorRect = %ColorBackground

@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var card_glow: ColorRect = %CardGlow

@onready var keyword_container = $Pivot/KeywordContainer
@onready var keyword_timer = $KeywordTimer

const KEYWORD_HOVER_DELAY: float = 0.5

signal card_selected(Card)
signal card_right_clicked(Card)
signal card_hovered(Card)
signal card_unhovered(Card)

func init(_card_data: CardData, angular_offset: float, connect_combat_signals: bool = false, connect_ui_signals: bool = true):
	card_data = _card_data
	pivot.rotation_degrees = angular_offset
	
	# signals used for cards in player's hand
	if connect_combat_signals:
		Signals.card_discarded.connect(_on_card_discarded)
		Signals.card_play_started.connect(_on_card_play_started)
		Signals.card_exhausted.connect(_on_card_exhausted)
		Signals.card_banished.connect(_on_card_banished)
		Signals.card_drawn.connect(_on_card_drawn)
		Signals.card_added_to_draw.connect(_on_card_added_to_draw)
		Signals.card_properties_changed.connect(_on_card_properties_changed)
		Signals.card_turn_energy_changed.connect(_on_card_turn_energy_changed)
		Signals.card_upgraded.connect(_on_card_upgraded)
		Signals.card_transformed.connect(_on_card_transformed)
	# flag to disable cards so they're not interactable by player
	if connect_ui_signals:
		card_button.gui_input.connect(_on_button_gui_input)
		card_button.mouse_entered.connect(_on_mouse_entered)
		card_button.mouse_exited.connect(_on_mouse_exited)
		keyword_timer.timeout.connect(_on_keyword_timeout)
	
	update_card_display()
	
	# initialize card listeners if in hand
	if Global.player_data.player_hand.has(card_data):
		card_listeners = _generate_card_listeners(card_data.card_listeners)
	

func update_card_display(selected_enemy: Enemy = null) -> void:
	if _card_is_rerendering:
		return
	if CARDS_RERENDER_LAZILY:
		_card_is_rerendering = true
		await get_tree().process_frame
		_card_is_rerendering = false
	
	# update visuals
	if card_data.card_texture_path != "":
		card_texture.texture = FileLoader.load_texture(card_data.card_texture_path)
	
	# updates the card's display
	card_name.set_bbcode("[center]" + card_data.get_card_name() + "[/center]")
	card_description.set_bbcode(get_card_description(selected_enemy))
	card_type.text = CardData.CARD_RARITIES.keys()[card_data.card_rarity] + " " + CardData.CARD_TYPES.keys()[card_data.card_type]
	
	var color_data: ColorData = Global.get_color_data(card_data.card_color_id)
	if color_data != null:
		card_color.color = color_data.color
	
	$Pivot/CardVisual/EnergySprite.visible = card_data.card_is_playable
	
	if card_data.card_energy_cost_is_variable:
		card_energy_cost.text = "X"
		if card_data.card_energy_cost_variable_upper_bound >= 1:
			card_energy_cost.text = "X-" + str(card_data.card_energy_cost_variable_upper_bound)
	else:
		card_energy_cost.text = str(card_data.get_card_energy_cost())

func set_card_glow(_visible: bool) -> void:
	card_glow.visible = _visible

func toggle_card_glow() -> void:
	card_glow.visible = !card_glow.visible

func can_play_card() -> bool:
	if not card_data.card_is_playable:
		return false
	if Global.player_data.player_energy < card_data.get_card_energy_cost():
		return false
	
	if not _validate_card():
		return false
	
	return true

func get_card_description(selected_target: BaseCombatant = null) -> String:
	# generates a card description for a card
	var modified_description_bb_code: String = card_data.card_description
	

	# generate fake card request
	var card_play_request: CardPlayRequest = CardPlayRequest.new()	# generate fake request
	card_play_request.card_data = card_data
	card_play_request.selected_target = selected_target
	
	# figure out what actions/values to calculate for the preview
	var card_description_preview_data: Array[Array] = []
	if len(card_data.card_description_preview_overrides) == 0:
		# with no overrides, assume basic block and attack
		card_description_preview_data = [
		 ["damage", Scripts.ACTION_ATTACK],
		 ["block", Scripts.ACTION_BLOCK]
		]
	else:
		# use the card's preview overrides
		card_description_preview_data = card_data.card_description_preview_overrides
	
	var player: Player = Global.get_player()
	
	# iterate over the preview data to determine any differences in the card's values
	for preview_data in card_description_preview_data:
		if len(preview_data) >= 2:
			var key_name: String = preview_data[0]
			var action_script_path: String = preview_data[1]
			
			if card_data.card_description.contains("[" + key_name + "]"):
				var action_data: Array[Dictionary] = [{action_script_path: {}}]
				var generated_action: BaseAction = ActionGenerator.create_actions(player, card_play_request, [selected_target], action_data, null)[0]
				var action_interceptor_processor: ActionInterceptorProcessor = generated_action._intercept_action([selected_target], true)[0]
				
				var card_value: int = card_data.card_values.get(key_name, 0)
				var value_substring: String = str(card_value)
				
				if action_interceptor_processor.shadowed_action_values.has(key_name):
					var intercepted_value: int = action_interceptor_processor.get_shadowed_action_values(key_name, card_value)
					
					# compare the intercepted valus to the card's values
					if intercepted_value < card_value:
						value_substring = "[color=red]" + str(intercepted_value) + "[/color]" # worse: red
					if intercepted_value > card_value:
						value_substring = "[color=green]" + str(intercepted_value) + "[/color]" # better: green
				
				modified_description_bb_code = modified_description_bb_code.replace("["+key_name+"]", value_substring)
			
	# do a second pass for non intercepted values in card description
	for key_name in card_data.card_values.keys():
		var non_intercepted_value: Variant = card_data.card_values[key_name]
		if non_intercepted_value is float:
			non_intercepted_value = int(non_intercepted_value)
		modified_description_bb_code = modified_description_bb_code.replace("["+key_name+"]", str(non_intercepted_value))
	
	# replace energy icon with external image bbcode
	if card_data.card_description.contains(ENERGY_ICON_KEYWORD):
		var character_data: CharacterData = Global.get_character_data(Global.player_data.player_character_object_id)
		if character_data != null:
			var image_bb_code: String = "[img width={0}]{1}[/img]".format([CARD_TEXT_IMAGE_SIZE, character_data.character_text_energy_texture_path])
			modified_description_bb_code = modified_description_bb_code.replace(ENERGY_ICON_KEYWORD, image_bb_code)
	
	return modified_description_bb_code

func _generate_card_listeners(listener_data: Array[Dictionary]) -> Array[BaseCardListener]:
	var generated_card_listeners: Array[BaseCardListener] = []
	for card_listener_data in listener_data:
		for card_listener_path in card_listener_data:
			var listener_asset = load(card_listener_path)
			var listener_values: Dictionary = card_listener_data[card_listener_path]
			var card_listener: BaseCardListener = listener_asset.new(self, listener_values)
			generated_card_listeners.append(card_listener)
	
	return generated_card_listeners

## Checks if card passes all validators to play it
func _validate_card() -> bool:
	return Global.validate(card_data.card_play_validators, card_data, null)

func _glow_validation() -> bool:
	# determines glow logic
	if len(card_data.card_glow_validators) == 0:
		if len(card_data.card_play_validators) > 0:
			return _validate_card() # if no glow validators use play validators
		else:
			return false
	else:
		# use glow validators
		return Global.validate(card_data.card_glow_validators, card_data, null)

func _is_card_in_hand() -> bool:
	return Global.player_data.player_hand.has(card_data)

func _attempt_hand_glow() -> void:
	# tests to see if cards in hand that require validation meet validation and glow
	if _is_card_in_hand():
		set_card_glow(_glow_validation())

func _on_button_gui_input(event: InputEvent):
	if event.is_action_pressed("left_click"):
		card_selected.emit(self)
	if event.is_action_pressed("right_click"):
		card_right_clicked.emit(self)

func _on_mouse_entered():
	keyword_timer.start(KEYWORD_HOVER_DELAY)
	card_hovered.emit(self)
	
func _on_mouse_exited():
	keyword_timer.stop()
	keyword_container.clear_keywords()
	card_unhovered.emit(self)

func _on_keyword_timeout():
	keyword_container.populate_card_keywords(card_data)

func _on_card_properties_changed(_card_data: CardData):
	if card_data == _card_data:
		update_card_display()

func _on_card_turn_energy_changed(_card_data: CardData):
	if card_data == _card_data:
		update_card_display()

func _on_card_upgraded(_card_data: CardData):
	if card_data == _card_data:
		update_card_display()

func _on_card_transformed(_card_data: CardData):
	if card_data == _card_data:
		# # reset card listeners to newly transformed card and rerender if in hand
		if Global.player_data.player_hand.has(card_data):
			card_listeners = _generate_card_listeners(card_data.card_listeners)
			update_card_display()

func _on_card_discarded(_card_data: CardData, _is_manual_discard: bool):
	if card_data == _card_data:
		queue_free()
	else:
		_attempt_hand_glow()

func _on_card_play_started(card_play_request: CardPlayRequest):
	if card_data == card_play_request.card_data:
		queue_free()
	else:
		_attempt_hand_glow()

func _on_card_exhausted(_card_data: CardData):
	if card_data == _card_data:
		queue_free()
	else:
		_attempt_hand_glow()

func _on_card_banished(_card_data: CardData, _in_limbo: bool):
	if card_data == _card_data:
		queue_free()
	else:
		_attempt_hand_glow()

func _on_card_drawn(_card_data: CardData):
	_attempt_hand_glow()

func _on_card_added_to_draw(_card_data: CardData):
	if card_data == _card_data:
		queue_free()
	else:
		_attempt_hand_glow()

func disconnect_non_ui_signals() -> void:
	# disconnects everything except internal clicking signals
	pass
