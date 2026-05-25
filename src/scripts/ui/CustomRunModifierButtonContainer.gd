extends ScrollContainer

@onready var v_box_container = $MarginContainer/VBoxContainer

var _run_modifier_object_id_to_checkbox: Dictionary = {}
var selected_custom_run_modififers: Array[String] = []

func populate_custom_run_modifiers() -> void:
	clear_custom_run_modifiers()
	
	var run_modifier_object_ids: Array = Global._id_to_run_modifier_data.keys()
	
	for run_modifier_object_id in run_modifier_object_ids:
		var run_modifier_data: RunModifierData = Global.get_run_modifier_data(run_modifier_object_id)
		if run_modifier_data.run_modifier_is_custom:
			var custom_run_modifier_checkbox: CheckBox = Scenes.CUSTOM_RUN_MODIFIER_CHECKBOX.instantiate()
			v_box_container.add_child(custom_run_modifier_checkbox)
			custom_run_modifier_checkbox.init(run_modifier_object_id)
			custom_run_modifier_checkbox.toggled.connect(_on_custom_run_modifier_toggled.bind(run_modifier_data))
			_run_modifier_object_id_to_checkbox[run_modifier_object_id] = custom_run_modifier_checkbox

func clear_custom_run_modifiers() -> void:
	_run_modifier_object_id_to_checkbox.clear()
	selected_custom_run_modififers.clear()
	for child in v_box_container.get_children():
		child.queue_free()

func _on_custom_run_modifier_toggled(toggle: bool, run_modifier_data: RunModifierData):
	if toggle:
		selected_custom_run_modififers.append(run_modifier_data.object_id)
		# uncheck any exclusive boxes
		for exclusive_run_modifier_object_id in run_modifier_data.run_modifier_exclusive_to_modifier_ids:
			selected_custom_run_modififers.erase(exclusive_run_modifier_object_id)
			var custom_run_modifier_checkbox: CheckBox = _run_modifier_object_id_to_checkbox.get(exclusive_run_modifier_object_id, null)
			if custom_run_modifier_checkbox != null:
				custom_run_modifier_checkbox.set_pressed_no_signal(false)
	else:
		selected_custom_run_modififers.erase(run_modifier_data.object_id)
