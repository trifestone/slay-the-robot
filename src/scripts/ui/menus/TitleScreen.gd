# title screen of game
# composed of sub menus with their own logic
# does nothing except control sub menu display logic
extends Control

@onready var main_menu = $MainMenu
@onready var new_run_menu = $NewRunMenu
@onready var codex_menu = $CodexMenu

func _ready():
	Signals.run_started.connect(_on_run_started)
	Signals.run_ended.connect(_on_run_ended)

func hide_menus():
	main_menu.visible = false
	new_run_menu.visible = false
	codex_menu.visible = false

func show_main_menu():
	hide_menus()
	main_menu.visible = true

func show_new_run_menu():
	hide_menus()
	new_run_menu.visible = true
	new_run_menu.populate_new_run_menu()

func show_codex_menu():
	hide_menus()
	codex_menu.visible = true
	codex_menu.populate_codex_menu()

func _on_run_started():
	visible = false

func _on_run_ended():
	visible = true
