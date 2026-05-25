extends Control

@onready var title_screen: Control = $%TitleScreen

@onready var character_name_label = $CharacterNameLabel
@onready var character_health_label = $CharacterHealthLabel
@onready var character_money_label = $CharacterMoneyLabel
@onready var character_description_label = $CharacterDescriptionLabel

@onready var character_artifact_texture_rect = $CharacterArtifactTextureRect
@onready var character_artifact_name_label = $CharacterArtifactNameLabel
@onready var character_artifact_description_label = $CharacterArtifactDescriptionLabel

@onready var decrease_difficulty_button = $DifficultySelect/DecreaseDifficultyButton
@onready var difficulty_label = $DifficultySelect/DifficultyLabel
@onready var increase_difficulty_button = $DifficultySelect/IncreaseDifficultyButton

@onready var custom_run_modifier_button_container = $CustomRunModifierButtonContainer

@onready var character_button_container = $CharacterButtonContainer

@onready var start_run_button: Button = $StartRunButton
@onready var seed_input: LineEdit = $SeedInput
@onready var back_button: Button = $BackButton

var selected_character_object_id: String = ""
var selected_difficulty_level: int = 0

func _ready():
	start_run_button.button_up.connect(_on_start_run_button_up)
	back_button.button_up.connect(_on_back_button_up)
	
	decrease_difficulty_button.button_up.connect(_on_decrease_difficulty_button)
	increase_difficulty_button.button_up.connect(_on_increase_difficulty_button)
	
	seed_input.text_changed.connect(_on_seed_input_text_changed)
	
	Signals.character_selected.connect(_on_character_selected)
	Signals.run_ended.connect(_on_run_ended)

func _on_seed_input_text_changed(new_text: String):
	# validate the input of the line edit
	var caret_column: int = seed_input.caret_column	# store cursor position as changing text resets it
	seed_input.text = str(new_text.to_int()) # validate inputs to only int
	seed_input.caret_column = min(caret_column, len(seed_input.text)) # reset the cursor position

func _on_character_selected(character_object_id: String):
	selected_character_object_id = character_object_id
	populate_character_info(selected_character_object_id)

func _on_decrease_difficulty_button():
	selected_difficulty_level = max(0, selected_difficulty_level -1)
	difficulty_label.text = "Difficulty " + str(selected_difficulty_level)
func _on_increase_difficulty_button():
	selected_difficulty_level = min(selected_difficulty_level + 1, len(PlayerData.DIFFICULTY_RUN_MODIFIER_OBJECT_IDS))
	difficulty_label.text = "Difficulty " + str(selected_difficulty_level)

func populate_new_run_menu() -> void:
	character_button_container.populate_character_buttons()
	custom_run_modifier_button_container.populate_custom_run_modifiers()

func populate_character_info(character_object_id: String) -> void:
	var character_data: CharacterData = Global.get_character_data(character_object_id)
	if character_data != null:
		character_name_label.text = character_data.character_name
		character_health_label.text = "HP: {0}".format([character_data.character_starting_health])
		character_money_label.text = "Money: {0}".format([character_data.character_starting_money])
		character_description_label.text = character_data.character_description
		
		# TODO potentially update ui to support multiple starter artifacts displayed
		if len(character_data.character_starting_artifact_ids) > 0:
			var artifact_data: ArtifactData = Global.get_artifact_data(character_data.character_starting_artifact_ids[0])
			if artifact_data != null:
				character_artifact_texture_rect.texture = FileLoader.load_texture(artifact_data.artifact_texture_path)
				character_artifact_name_label.text = artifact_data.artifact_name
				character_artifact_description_label.text = artifact_data.artifact_description

func _on_start_run_button_up():
	# get the seed and start the run
	var run_seed: int = seed_input.text.to_int()
	Global.start_run(selected_character_object_id, run_seed, selected_difficulty_level, custom_run_modifier_button_container.selected_custom_run_modififers)

func _on_back_button_up():
	title_screen.show_main_menu()

func _on_run_ended():
	# go back to tile screen on failed run, but not abandoned run
	var has_save_file: bool = FileLoader.has_save_file()
	visible = not has_save_file
	populate_new_run_menu()
