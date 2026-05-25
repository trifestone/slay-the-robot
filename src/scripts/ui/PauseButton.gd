# UI element that pauses the game
extends TextureButton

@onready var map: Control = %Map
@onready var shop_overlay: Control = %ShopOverlay

func _ready() -> void:
	pressed.connect(_on_pause_button_pressed)
	
	Signals.game_paused.connect(_on_game_paused)
	Signals.game_unpaused.connect(_on_game_unpaused)
	
func _on_pause_button_pressed() -> void:
	Global.pause_game()

func _on_game_paused() -> void:
	if _is_game_pausable():
		disabled = true

func _on_game_unpaused() -> void:
	disabled = false

# returns whether the pausing should be allowed to work
# NOTE: Override this to change pausing logic
func _is_game_pausable() -> bool:
	if not Global.is_run:
		return false
	if map.visible:
		return false
	return true
