extends Control

@onready var turn_label: Label = $TurnLabel

func update_turn_label() -> void:
	# called from animation player
	turn_label.text = "Turn %s" % Global.get_combat_stats().turn_count
