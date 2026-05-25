## UI menu to display all content in the game such as all cards
extends Control

@onready var title_screen: Control = $%TitleScreen
@onready var back_button: Button = $BackButton
@onready var codex_card_container: GridContainer = $ScrollContainer/MarginContainer/CodexCardContainer

func _ready():
	back_button.button_up.connect(_on_back_button_up)

func populate_codex_menu() -> void:
	populate_codex_card_container()

func populate_codex_card_container() -> void:
	# creates all cards in the game to display
	var card_object_ids: Array = Global._id_to_card_data.keys()

	for card_object_id: String in card_object_ids:
		var card_data: CardData = Global.get_card_data(card_object_id)
		
		# generate an un-interactable card object for display
		var card: Card = Scenes.CARD.instantiate()
		codex_card_container.add_child(card)
		card.init(card_data, 0, false, false)

func clear_codex_card_container() -> void:
	for child in codex_card_container.get_children():
		child.queue_free()

func _on_back_button_up():
	clear_codex_card_container()
	title_screen.show_main_menu()
