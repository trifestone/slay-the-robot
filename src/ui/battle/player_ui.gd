## PlayerUI — decorative player avatar shown on the left side of the battle scene.
## Displays player HP via a label and progress bar. Pure visual; no input handling.
extends Control

@onready var _hp_label: Label       = $HpLabel
@onready var _hp_bar:   ProgressBar = $HpBar


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


## Update the HP display. Guards against divide-by-zero when max_hp is 0.
func bind(player_hp: int, max_hp: int) -> void:
	_hp_label.text = "生命 %d/%d" % [player_hp, max_hp]
	if max_hp > 0:
		_hp_bar.value = float(player_hp) / float(max_hp)
	else:
		_hp_bar.value = 0.0
