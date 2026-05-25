## Read only data providing the topology of an act. See: ActionGenerateAct.
extends SerializableData
class_name ActData

## How the act should appear in text.
@export var act_name: String = "Act 1"
## The path to the script used to generate this act. You can change this to enable
## custom act generation
@export var act_action_script_path: String = Scripts.ACTION_GENERATE_ACT

## The event pool for this act's easy combats. Used for generation of locations in this act.
@export var act_easy_combat_event_pool_object_id: String = ""

## The event pool for this act's hard combats. Used for generation of locations in this act.
@export var act_hard_combat_event_pool_object_id: String = ""

## The event pool for non combat events. Used for generation of locations in this act.
@export var act_non_combat_event_pool_object_id: String = ""

## The pool for the miniboss events of the act
@export var act_miniboss_event_pool_object_id: String = ""

## The pool for the boss event at the end of the act
@export var act_boss_event_pool_object_id: String = ""

## The potential acts that can come after this one. Not having another act after this will result in no
## more acts being generated and the run ending. If multiple are provided one will randomly be chosen.
@export var act_next_act_ids: Array[String] = []

## A path to an external texture file to use for this act.
@export var act_background_texture_path: String = ""
