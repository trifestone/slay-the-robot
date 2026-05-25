# read only data for a type of consumable
extends SerializableData
class_name ConsumableData

@export var consumable_name: String = ""	# how this appears in tooltips
@export var consumable_description: String = ""	# how this appears in tooltips
@export var consumable_texture_path: String = "res://icon.svg"	# display texture path for the consumable

@export var consumable_requires_target: bool = false	# if the consumable requires clicking on an enemy

enum CONSUMABLE_RARITIES {COMMON, UNCOMMON, RARE, LEGENDARY}
@export var consumable_rarity: int = CONSUMABLE_RARITIES.COMMON

@export var consumable_actions: Array[Dictionary] = []	# actions performed when the consumable is used
