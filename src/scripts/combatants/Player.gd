# Player UI element
extends BaseCombatant
class_name Player

@onready var incoming_damage: Control = $Visible/IncomingDamage
@onready var incoming_damage_amount_text: Label = $Visible/IncomingDamage/IncomingDamageAmount

const INTENT_UPDATES_LAZILY: bool = true	# batches intent updates
var _intent_is_updating: bool = false

func _ready():
	super()
	Signals.enemy_intent_changed.connect(_on_enemy_intent_changed)
	Signals.enemy_death_animation_finished.connect(_on_enemy_death_animation_finished)
	Signals.player_health_changed.connect(_on_player_health_changed)
	Signals.artifact_proc.connect(_on_artifact_proc)
	Signals.run_started.connect(_on_run_started)
	Signals.run_ended.connect(_on_run_ended)

## Does damage to combatant and returns [unblocked damage dealt, damage to 0 (if player dies), overkill damage (if player dies)].
## eg 15 damage on 10 remaining health and 3 block will return [12, 10, 2].
## bypass_block = true will do damage directly to health.
func damage(_damage: int, bypass_block: bool = false) -> Array[int]:
	var player_data: PlayerData = Global.player_data
	
	var bypassed_damage: int = _damage # raw unblocked damage
	var bypassed_damage_capped: int = 0 # damage done that does not factor in overkill damage
	var overkill_damage: int = 0 # damage done past 0

	if player_data.player_block > 0 and not bypass_block:
		if player_data.player_block > _damage:
			# damage less than block
			player_data.player_block -= _damage
			bypassed_damage = 0
			create_block_text()
			Signals.combatant_blocked.emit(self, _damage)
		else:
			# damage exceeds block
			bypassed_damage = _damage - player_data.player_block
			player_data.player_block = 0
			Signals.combatant_block_broken.emit(self)
	
	block.visible = player_data.player_block > 0
	block_amount.text = str(player_data.player_block)
	
	if bypassed_damage <= 0:
		return [0,0,0]
	
	create_damage_text(bypassed_damage)
	overkill_damage = max(0, bypassed_damage - player_data.player_health)
	bypassed_damage_capped = bypassed_damage - overkill_damage
	
	if player_data.player_health > 0:
		player_data.add_health(-bypassed_damage)
		Signals.combatant_damaged.emit(self, bypassed_damage)
		
	return [bypassed_damage, bypassed_damage_capped, overkill_damage]

func set_block(amount: int) -> void:
	Global.player_data.player_block = amount
	Global.player_data.player_block = max(0, Global.player_data.player_block)
	
	block.visible = Global.player_data.player_block > 0
	block_amount.text = str(Global.player_data.player_block)

func get_block() -> int:
	return 	Global.player_data.player_block

func add_block(amount: int) -> void:
	set_block(Global.player_data.player_block + amount)
	if amount > 0:
		Signals.combatant_block_added.emit(self)

func update_health_bar(as_damage: bool = false) -> void:
	var player_data: PlayerData = Global.player_data
	if as_damage:
		layered_health_bar.apply_damage(player_data.player_health, player_data.player_health_max, status_id_to_status_effects)
	else:
		layered_health_bar.update_health_layers(player_data.player_health, player_data.player_health_max, status_id_to_status_effects)

func update_player_display(_player_data: PlayerData):
	update_health_bar(false)

func update_incoming_damage_amount(recalculate_enemy_intent: bool = true) -> void:
	# updates the damage preview above the player's head
	# flag to force recalculation of all enemy intents as well
	
	# optional lazy updating
	if _intent_is_updating:
		return
	if INTENT_UPDATES_LAZILY:
		_intent_is_updating = true
		await get_tree().process_frame
		_intent_is_updating = false
	
	var incoming_damage_amount = 0 # totaled value
	for en in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = en # typecast
		
		if recalculate_enemy_intent:
			enemy.update_enemy_intent()
		
		incoming_damage_amount += enemy.enemy_intent_attack_damage * enemy.enemy_intent_number_of_attacks

	incoming_damage_amount_text.text = str(incoming_damage_amount)
	incoming_damage.visible = incoming_damage_amount > 0

func is_alive() -> bool:
	return Global.player_data.player_health > 0

func create_artifact_fade(artifact_id: String) -> void:
	var artifact_fade: ArtifactFade = Scenes.ARTIFACT_FADE.instantiate()
	fade_container.add_child(artifact_fade)
	artifact_fade.init(artifact_id)

### Run Modifiers

func register_run_modifier_interceptors() -> void:
	# attaches intercepotors from modifiers to the player
	for run_modifier_object_id in Global.player_data.player_run_modifier_object_ids:
		var run_modifier_data: RunModifierData = Global.get_run_modifier_data(run_modifier_object_id)
		if run_modifier_data == null:
			push_error("No RunData with id of ", run_modifier_object_id)
		else:
			for interceptor_id in run_modifier_data.run_modifier_interceptor_script_paths:
				ActionHandler.register_action_interceptor(self, interceptor_id)


func _on_run_started():
	var character_data: CharacterData = Global.get_player_character_data()
	sprite.texture = FileLoader.load_texture(character_data.character_texture_path)
	
	reset_block()
	clear_all_status_effects()
	unregister_all_custom_ui()
	
	# reinitialize healthbar
	var player_data: PlayerData = Global.player_data
	layered_health_bar.init(player_data.player_health, player_data.player_health_max)
	update_health_bar(false)
	
	update_incoming_damage_amount(true)
	# run modifiers
	register_run_modifier_interceptors()
	
	# reset animation and state
	var location_data: LocationData = Global.get_player_location_data()
	if location_data.location_type == LocationData.LOCATION_TYPES.STARTING:
		animation_player.play("run_start")

func _on_run_ended():
	reset_block()
	clear_all_status_effects()
	unregister_all_custom_ui()

func _on_combat_started(_event_id: String):
	clear_all_status_effects()
	
func _on_combat_ended():
	clear_all_status_effects()
	reset_block()
	update_incoming_damage_amount()

func _on_enemy_intent_changed():
	update_incoming_damage_amount(true)

func _on_enemy_death_animation_finished(_enemy: Enemy):
	update_incoming_damage_amount()

func _on_player_health_changed():
	update_health_bar(true)
	if Global.player_data.player_health <= 0:
		if not animation_player.is_playing():
			animation_player.play("death")
			Signals.player_killed.emit(self)

func _on_artifact_proc(artifact_data: ArtifactData):
	create_artifact_fade(artifact_data.object_id)

func _on_death_animtation_finished():
	# called from animation player
	Signals.player_death_animation_finished.emit(self)
