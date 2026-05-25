# abstract interface for a run modifier or difficulty
extends RefCounted
class_name BaseRunModifier

func run_start_modification() -> void:
	# any custom logic done at the start of a run
	pass
