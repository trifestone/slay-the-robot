extends BaseAction

func perform_action():
	var damage: int = get_action_value("damage", 0)
	var adjusted_targets: Array[BaseCombatant] = get_adjusted_action_targets()
	for target in adjusted_targets:
		var _damages: Array[int] = target.damage(damage, true)

func _to_string():
	var damage: int = get_action_value("damage", 0)
	return "Attack Corrosion: " + str(damage)
