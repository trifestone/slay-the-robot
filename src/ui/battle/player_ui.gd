## PlayerUI — decorative player avatar shown on the left side of the battle scene.
## Displays player HP + block shield via labels and progress bars.
extends Control

@onready var _hp_label: Label       = $HpLabel
@onready var _hp_bar:   ProgressBar = $HpBar
@onready var _shield_icon: Control  = $ShieldIcon
@onready var _block_bar: ProgressBar = $BlockBar
@onready var _block_label: Label    = $BlockLabel


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_update_block_display(0)


## Update the HP display. Guards against divide-by-zero when max_hp is 0.
func bind(player_hp: int, max_hp: int, player_block: int = 0) -> void:
	_hp_label.text = "生命 %d/%d" % [player_hp, max_hp]
	if max_hp > 0:
		_hp_bar.value = float(player_hp) / float(max_hp)
	else:
		_hp_bar.value = 0.0
	_update_block_display(player_block)


func _update_block_display(block: int) -> void:
	_shield_icon.visible = block > 0
	_block_bar.visible = block > 0
	_block_label.visible = block > 0
	if block > 0:
		_block_label.text = "格挡 %d" % block
		_block_bar.value = float(block)
	else:
		_block_label.text = "格挡 0"
		_block_bar.value = 0.0
