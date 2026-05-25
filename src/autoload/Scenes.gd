extends Node

var CARD: PackedScene = load("res://scenes/ui/Card.tscn")

var ARTIFACT: PackedScene = load("res://scenes/ui/Artifact.tscn")

var MAP_LOCATION: PackedScene = load("res://scenes/ui/MapLocation.tscn")

var ENEMY: PackedScene = load("res://scenes/combatants/Enemy.tscn")
var PLAYER: PackedScene = load("res://scenes/combatants/Player.tscn")
var STATUS_EFFECT: PackedScene = load("res://scenes/combatants/StatusEffect.tscn")
var HEALTH_LAYER = load("res://scenes/combatants/HealthLayer.tscn")

var BASE_REWARD_BUTTON: PackedScene = load("res://scenes/ui/rewards/BaseRewardButton.tscn")
var MONEY_REWARD_BUTTON: PackedScene = load("res://scenes/ui/rewards/MoneyRewardButton.tscn")
var CARD_REWARD_BUTTON: PackedScene = load("res://scenes/ui/rewards/CardRewardButton.tscn")
var ARTIFACT_REWARD_BUTTON: PackedScene = load("res://scenes/ui/rewards/ArtifactRewardButton.tscn")

var REST_ACTION_BUTTON: PackedScene = load("res://scenes/ui/RestActionButton.tscn")

var CONSUMABLE_BUTTON: PackedScene = load("res://scenes/ui/ConsumableButton.tscn")
var CHARACTER_SELECTION_BUTTON: PackedScene = load("res://scenes/ui/CharacterSelectionButton.tscn")

var CUSTOM_RUN_MODIFIER_CHECKBOX: PackedScene = load("res://scenes/ui/CustomRunModifierCheckbox.tscn")

var BASE_SHOP_BUTTON: PackedScene = load("res://scenes/ui/shop/BaseShopButton.tscn")
var CARD_SHOP_BUTTON: PackedScene = load("res://scenes/ui/shop/CardShopButton.tscn")
var ARTIFACT_SHOP_BUTTON: PackedScene = load("res://scenes/ui/shop/ArtifactShopButton.tscn")
var CONSUMABLE_SHOP_BUTTON: PackedScene = load("res://scenes/ui/shop/ConsumableShopButton.tscn")

var TEXT_FADE: PackedScene = load("res://scenes/combatants/fades/TextFade.tscn")
var ARTIFACT_FADE: PackedScene = load("res://scenes/combatants/fades/ArtifactFade.tscn")

var KEYWORD_TOOLTIP: PackedScene = load("res://scenes/ui/general/KeywordTooltip.tscn")
var TOOLTIP: PackedScene = load("res://scenes/ui/general/Tooltip.tscn")
var DIALOGUE_OPTION = load("res://scenes/ui/general/DialogueOption.tscn")
