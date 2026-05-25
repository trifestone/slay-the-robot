# data about things happening in combat, such as cards played, damage taken etc
# only stores stats for a single instance of combat
extends SerializableData
class_name CombatStatsData

@export var event_object_id: String = "" # the event id used in this combat

var cards_played_this_turn: Array[CardPlayRequest] = []
var cards_played_this_combat: Array[Array] = []
@export var turn_count: int = 1

## Tracks whether it is currently the player's turn in a central location.
var is_player_turn: bool = false

# stat types tracked on per turn and per combat
# each stat listed in enum will automatically be used to generate stat tracking keys in init()
enum STATS {
	ENEMY_BLOCK_BROKEN_COUNT,		# number of times enemy's block has been broken through
	ENEMY_BLOCKED_COUNT,			# number of times an enemy blocked an attack
	ENEMY_BLOCKED_AMOUNT,			# total amount of blocked damage by enemy
	ENEMY_DAMAGED_COUNT,			# number of times enemy has taken non zero health damage
	ENEMY_DAMAGED_AMOUNT,			# total health damage by enemies
	ENEMIES_KILLED,					# number of enemies killed
	
	PLAYER_BLOCK_BROKEN_COUNT,		# number of times player's block has been broken through
	PLAYER_BLOCKED_COUNT,			# total amount of blocked damage by player
	PLAYER_BLOCKED_AMOUNT,			# total amount of blocked damage by player
	PLAYER_DAMAGED_COUNT,			# number of times player has taken non zero health damage
	PLAYER_DAMAGED_AMOUNT,			# total health damage by player
	
	CARDS_PLAYED,					# number of cards played
	CARDS_DRAWN,					# number of cards drawn
	CARDS_DISCARDED,				# number of cards discarded
	CARDS_EXHAUSTED,				# number of cards exhausted
	CARDS_BANISHED,					# number of cards banished
	CARDS_RETAINED,					# number of cards retained
	CARDS_UPGRADED,					# number of cards upgraded mid combat
	CARDS_CREATED,					# number of cards created mid combat
	DECK_RESHUFFLED					# number of times deck was reshuffled (initial shuffling not counted)
}

@export var turn_stats: Dictionary = {}	# maintains numberical stats on all trackable things done this turn 
@export var total_stats: Dictionary = {} # maintains numberical stats on all trackable things done this combat

func _init(_event_object_id: String = ""):
	event_object_id = _event_object_id
	
	_connect_signals()
	# assign zero stats
	for key: String in STATS.keys():
		turn_stats[key] = 0
		total_stats[key] = 0
	for custom_signal_object_id in Global._id_to_custom_signal_data.keys():
		var custom_signal_data: CustomSignalData = Global.get_custom_signal_data(custom_signal_object_id)
		if custom_signal_data.custom_signal_is_stat:
			turn_stats[custom_signal_data.custom_signal_stat_name] = 0
			total_stats[custom_signal_data.custom_signal_stat_name] = 0

#region Signals
func _connect_signals():
	Signals.player_turn_started.connect(_on_player_turn_started)
	Signals.player_turn_ended.connect(_on_player_turn_ended)
	
	Signals.enemy_turn_ended.connect(_on_enemy_turn_ended)
	Signals.card_played.connect(_on_card_played)
	Signals.combat_ended.connect(_on_combat_ended)
	### stats
	Signals.combatant_block_broken.connect(_on_combatant_block_broken)
	Signals.combatant_blocked.connect(_on_combatant_blocked)
	Signals.combatant_damaged.connect(_on_combatant_damaged)
	Signals.enemy_killed.connect(_on_enemy_killed)
	
	Signals.card_drawn.connect(_on_card_drawn)
	Signals.card_discarded.connect(_on_card_discarded)
	Signals.card_exhausted.connect(_on_card_exhausted)
	Signals.card_banished.connect(_on_card_banished)
	Signals.card_retained.connect(_on_card_retained)
	Signals.card_upgraded.connect(_on_card_upgraded)
	Signals.card_created.connect(_on_card_created)
	
	Signals.card_deck_shuffled.connect(_on_card_deck_shuffled)
	
	_connect_custom_signals()

func _connect_custom_signals() -> void:
	# iterate over all custom signals that are stats and connect to them
	for custom_signal_object_id in Global._id_to_custom_signal_data.keys():
		var custom_signal_data: CustomSignalData = Global.get_custom_signal_data(custom_signal_object_id)
		if custom_signal_data.custom_signal_is_stat:
			var custom_signal: CustomSignal = Signals.get_custom_signal(custom_signal_object_id)
			custom_signal.custom_signal.connect(_on_custom_signal)

func _disconnect_signals():
	# disconnect all signals to prevent stats being tracked across multiple combats
	for connection in get_incoming_connections():
		connection.signal.disconnect(connection.callable)
#endregion

#region Turns/Combat
func _on_player_turn_started():
	is_player_turn = true

func _on_player_turn_ended():
	is_player_turn = false

func _on_enemy_turn_ended():
	turn_count += 1
	_reset_turn_stats()
	# move cards played over and reset it
	cards_played_this_combat.append(cards_played_this_turn)
	cards_played_this_turn = []

func _on_combat_ended():
	# remove these to save card plays after they're not needed for run history
	cards_played_this_combat.clear()
	cards_played_this_turn.clear()
	
	# keep this to prevent stat tracks after combat
	_disconnect_signals()
#endregion

#region Custom Signals

func _on_custom_signal(custom_signal_id: String, values: Dictionary[String, Variant]) -> void:
	var custom_signal_data: CustomSignalData = Global.get_custom_signal_data(custom_signal_id)
	var stat_amount: int = values["value_amount"]
	add_to_custom_stat(custom_signal_data.custom_signal_stat_name, stat_amount)

#region Card Plays

func _on_card_played(card_play_request: CardPlayRequest) -> void:
	cards_played_this_turn.append(card_play_request)
	add_to_enum_stat(STATS.CARDS_PLAYED, 1)

func get_turn_last_card_play() -> CardPlayRequest:
	# gets the card last played, if one exists
	if len(cards_played_this_turn) > 0:
		return cards_played_this_turn[-1]
	return null

func get_card_data_played_this_turn(include_duplicates: bool = false) -> Array[CardData]:
	# gets all cards played this turn, with option to cull duplicate cards
	var cards_played: Array[CardData] = []
	for card_play_request in cards_played_this_turn:
		if include_duplicates:
			cards_played.append(card_play_request.card_data)
		else:
			if not cards_played.has(card_play_request.card_data):
				cards_played.append(card_play_request.card_data)
	return cards_played

func get_card_data_played_last_turn(include_duplicates: bool = false) -> Array[CardData]:
	# gets all cards played last turn, with option to cull duplicate cards
	var cards_played: Array[CardData] = []
	if turn_count <= 1:
		return []	# 1st turn, no previous turn
	
	for card_play_request in cards_played_this_combat[turn_count - 2]:
		if include_duplicates:
			cards_played.append(card_play_request.card_data)
		else:
			if not cards_played.has(card_play_request.card_data):
				cards_played.append(card_play_request.card_data)
	return cards_played
#endregion

#region Stat Tracking
func _reset_turn_stats() -> void:
	for stat_name in turn_stats:
		turn_stats[stat_name] = 0

func _get_stat_name(stat_enum: int) -> String:
	# helper method to convert stat enum to string representation
	if stat_enum < len(STATS.keys()):
		return STATS.keys()[stat_enum]
	else:
		breakpoint
	return ""

## Adds a value to this turn's stats for a given hard coded CombatStatsData.STATS
func add_to_enum_stat(stat_enum: int, stat_amount: int) -> void:
	var stat_name: String = _get_stat_name(stat_enum)
	turn_stats[stat_name] = turn_stats[stat_name] + stat_amount
	total_stats[stat_name] = total_stats[stat_name] + stat_amount
	Signals.combat_stat_changed.emit(stat_enum)

## Adds a value to a given custom stat.
func add_to_custom_stat(stat_name: String, stat_amount: int) -> void:
	# adds a value to this turn's stats
	turn_stats[stat_name] = turn_stats[stat_name] + stat_amount
	total_stats[stat_name] = total_stats[stat_name] + stat_amount

func get_turn_stat(stat_enum: int) -> int:
	var stat_name: String = _get_stat_name(stat_enum)
	return turn_stats[stat_name]

func get_total_stat(stat_enum: int) -> int:
	var stat_name: String = _get_stat_name(stat_enum)
	return total_stats[stat_name]
#endregion

#region Stat Tracking Hooks

func _on_combatant_block_broken(base_combatant: BaseCombatant):
	if base_combatant.is_in_group("enemies"):
		add_to_enum_stat(STATS.ENEMY_BLOCK_BROKEN_COUNT, 1)
	if base_combatant.is_in_group("players"):
		add_to_enum_stat(STATS.PLAYER_BLOCK_BROKEN_COUNT, 1)
func _on_combatant_blocked(base_combatant: BaseCombatant, amount_blocked: int):
	if base_combatant.is_in_group("enemies"):
		add_to_enum_stat(STATS.ENEMY_BLOCKED_AMOUNT, amount_blocked)
		add_to_enum_stat(STATS.ENEMY_BLOCKED_COUNT, 1)
	if base_combatant.is_in_group("players"):
		add_to_enum_stat(STATS.PLAYER_BLOCKED_AMOUNT, amount_blocked)
		add_to_enum_stat(STATS.PLAYER_BLOCKED_AMOUNT, 1)
func _on_combatant_damaged(base_combatant: BaseCombatant, unblocked_damage: int):
	if base_combatant.is_in_group("enemies"):
		add_to_enum_stat(STATS.ENEMY_DAMAGED_AMOUNT, unblocked_damage)
		add_to_enum_stat(STATS.ENEMY_DAMAGED_COUNT, 1)
	if base_combatant.is_in_group("players"):
		add_to_enum_stat(STATS.PLAYER_DAMAGED_AMOUNT, unblocked_damage)
		add_to_enum_stat(STATS.PLAYER_DAMAGED_COUNT, 1)

func _on_enemy_killed(_enemy: Enemy):
	add_to_enum_stat(STATS.ENEMIES_KILLED, 1)

func _on_card_drawn(_card_data: CardData) -> void:
	add_to_enum_stat(STATS.CARDS_DRAWN, 1)
func _on_card_discarded(_card_data: CardData, is_manual_discard: bool) -> void:
	if is_manual_discard:
		add_to_enum_stat(STATS.CARDS_DISCARDED, 1)
func _on_card_exhausted(_card_data: CardData) -> void:
	add_to_enum_stat(STATS.CARDS_EXHAUSTED, 1)
func _on_card_banished(_card_data: CardData, in_limbo: bool) -> void:
	if not in_limbo:
		add_to_enum_stat(STATS.CARDS_EXHAUSTED, 1)
func _on_card_retained(_card_data: CardData) -> void:
	add_to_enum_stat(STATS.CARDS_RETAINED, 1)
func _on_card_upgraded(_card_data: CardData) -> void:
	add_to_enum_stat(STATS.CARDS_UPGRADED, 1)
func _on_card_created(_card_data: CardData) -> void:
	add_to_enum_stat(STATS.CARDS_CREATED, 1)
	
func _on_card_deck_shuffled(is_reshuffle: bool) -> void:
	if is_reshuffle:
		add_to_enum_stat(STATS.DECK_RESHUFFLED, 1)

#endregion
