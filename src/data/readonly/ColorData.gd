## Maps a simple color, reusable throughout the framework
extends SerializableData
class_name ColorData

@export var color: Color = Color.WHITE

func _get_native_properties() -> Dictionary:
	return {
		"color": Color(),
	}
