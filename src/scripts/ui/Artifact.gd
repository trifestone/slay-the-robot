## UI element for an artifact.
## Supports being right clicked to activate effects
extends TextureButton

var artifact_data: ArtifactData
var artifact_script: BaseArtifact

@onready var counter_label: Label = $CounterLabel
@onready var animation_player: AnimationPlayer = $AnimationPlayer

func _ready():
	Signals.artifact_proc.connect(_on_artifact_proc)
	Signals.artifact_counter_changed.connect(_on_artifact_counter_changed)

func init(_artifact_data: ArtifactData):
	artifact_data = _artifact_data
	var artifact_script_asset: Resource = load(artifact_data.artifact_script_path)
	artifact_script = artifact_script_asset.new(artifact_data)
	texture_normal = FileLoader.load_texture(artifact_data.artifact_texture_path)
	update_artifact_counter()
	
	tooltip_text = artifact_data.artifact_name
	if artifact_data.artifact_description != "":
		if len(artifact_data.ARTIFACT_RARITIES.keys()) > artifact_data.artifact_rarity:
			tooltip_text += "\n" + artifact_data.ARTIFACT_RARITIES.keys()[artifact_data.artifact_rarity]
		tooltip_text += "\n" + artifact_data.artifact_description
	
	# only right clicking allowed
	button_up.connect(_on_right_button_up)

func _on_artifact_proc(_artifact_data: ArtifactData):
	if artifact_data == _artifact_data:
		animation_player.play("proc_anim")

func _on_artifact_counter_changed(_artifact_data: ArtifactData):
	if artifact_data == _artifact_data:
		update_artifact_counter()

func update_artifact_counter() -> void:
	if artifact_data != null:
		if artifact_data.artifact_counter == 0:
			counter_label.text = ""
		else:
			counter_label.text = str(artifact_data.artifact_counter)

func _on_right_button_up() -> void:
	artifact_script.right_click_artifact()
