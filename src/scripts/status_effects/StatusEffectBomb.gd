# status that does damage equal to secondary charges when it counts down
extends BaseStatusEffect

func perform_status_effect_actions() -> void:
	if status_charges == 1:
		super()
