extends Control

@onready var victory_label = $VictoryLabel
@onready var defeat_label = $DefeatLabel

@onready var end_run_button = $EndRunButton

var player_run_end_state: int = Global.RUN_ENDS.QUIT # store if the player won or lost in the ui

func _ready():
	end_run_button.button_up.connect(_on_end_run_button_up)
	Signals.combat_ended.connect(_on_combat_ended)
	Signals.run_started.connect(_on_run_started)
	Signals.run_ended.connect(_on_run_ended)
	Signals.run_victory.connect(_on_run_victory)
	Signals.player_death_animation_finished.connect(_on_player_death_animation_finished)

func _on_combat_ended():
	if Global.is_end_of_run():
		visible = true
		Signals.run_victory.emit()

func _on_run_started():
	visible = false
		
func _on_run_ended():
	visible = false
	
func _on_run_victory():
	victory_label.visible = true
	defeat_label.visible = false
	visible = true
	player_run_end_state = Global.RUN_ENDS.VICTORY
	
func _on_player_death_animation_finished(_player: Player):
	victory_label.visible = false
	defeat_label.visible = true
	visible = true
	player_run_end_state = Global.RUN_ENDS.LOSS

func _on_end_run_button_up():
	visible = false
	Global.end_run(player_run_end_state)
