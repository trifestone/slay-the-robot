# Hardcoded script paths
extends Node

#region Action scripts

# map generation actions
const ACTION_GENERATE_ACT: String = "res://scripts/actions/world_generation_actions/ActionGenerateAct.gd"

# map interaction actions
const ACTION_VISIT_LOCATION: String = "res://scripts/actions/world_interaction_actions/ActionVisitLocation.gd"
const ACTION_OPEN_CHEST: String = "res://scripts/actions/world_interaction_actions/ActionOpenChest.gd"
const ACTION_START_COMBAT: String = "res://scripts/actions/world_interaction_actions/ActionStartCombat.gd"

# general combat actions

const ACTION_RESET_BLOCK: String = "res://scripts/actions/ActionResetBlock.gd"
const ACTION_BLOCK: String = "res://scripts/actions/ActionBlock.gd"
const ACTION_DIRECT_DAMAGE: String = "res://scripts/actions/ActionDirectDamage.gd"
const ACTION_ADD_ENERGY: String = "res://scripts/actions/ActionAddEnergy.gd"
const ACTION_APPLY_STATUS: String = "res://scripts/actions/status_actions/ActionApplyStatus.gd"
const ACTION_DECAY_STATUS: String = "res://scripts/actions/status_actions/ActionDecayStatus.gd"
const ACTION_SUMMON_ENEMIES: String = "res://scripts/actions/ActionSummonEnemies.gd"
const ACTION_END_TURN: String = "res://scripts/actions/ActionEndTurn.gd"
const ACTION_RESHUFFLE: String = "res://scripts/actions/ActionReshuffle.gd"

# status actions, created by StatusEffect scripts
const ACTION_CORROSION: String = "res://scripts/actions/status_actions/ActionCorrosion.gd"

# custom ui
const ACTION_CUSTOM_UI: String = "res://scripts/actions/custom_ui_actions/ActionCustomUI.gd"

# debug
const ACTION_DEBUG_LOG = "res://scripts/actions/debug_actions/ActionDebugLog.gd"

# card play
const ACTION_CARD_PLAY: String = "res://scripts/actions/meta_actions/ActionCardPlay.gd"
const ACTION_CARD_PLAY_END: String = "res://scripts/actions/meta_actions/ActionCardPlayEnd.gd"

# meta actions; actions that generate or affect other actions, or some other technical effect
const ACTION_ATTACK_GENERATOR: String = "res://scripts/actions/meta_actions/ActionAttackGenerator.gd"
const ACTION_DRAW_GENERATOR: String = "res://scripts/actions/meta_actions/ActionDrawGenerator.gd"
const ACTION_EMIT_CUSTOM_SIGNAL: String = "res://scripts/actions/meta_actions/ActionEmitCustomSignal.gd"
const ACTION_VARIABLE_COST_MODIFIER: String = "res://scripts/actions/meta_actions/ActionVariableCostModifier.gd"
const ACTION_VARIABLE_CARDSET_MODIFIER: String = "res://scripts/actions/meta_actions/ActionVariableCardsetModifier.gd"
const ACTION_VARIABLE_COMBAT_STATS_MODIFIER: String = "res://scripts/actions/meta_actions/ActionVariableCombatStatsModifier.gd"
const ACTION_VALIDATOR: String = "res://scripts/actions/meta_actions/ActionValidator.gd"

# generated actions; use their corresponding generator to make these
const ACTION_ATTACK: String = "res://scripts/actions/generated_actions/ActionAttack.gd"
const ACTION_DRAW: String = "res://scripts/actions/generated_actions/ActionDraw.gd"

# progression actions
const ACTION_ADD_HEALTH: String = "res://scripts/actions/ActionAddHealth.gd"
const ACTION_HEAL_PERCENT: String =  "res://scripts/actions/ActionHealPercent.gd"

const ACTION_ADD_ARTIFACT: String = "res://scripts/actions/player_actions/ActionAddArtifact.gd"
const ACTION_SWAP_BOSS_ARTIFACT: String = "res://scripts/actions/player_actions/ActionSwapBossArtifact.gd"
const ACTION_ADD_MONEY: String = "res://scripts/actions/player_actions/ActionAddMoney.gd"
const ACTION_UPDATE_DRAFT_CARDS = "res://scripts/actions/player_actions/ActionUpdateCardDrafts.gd"
const ACTION_UPDATE_REST_ACTIONS = "res://scripts/actions/player_actions/ActionUpdateRestActions.gd"
const ACTION_ADD_CONSUMABLE: String = "res://scripts/actions/player_actions/ActionAddConsumable.gd"
const ACTION_USE_CONSUMABLE: String = "res://scripts/actions/player_actions/ActionUseConsumable.gd"

# reward actions
const ACTION_GRANT_REWARDS = "res://scripts/actions/rewards/ActionGrantRewards.gd"
const ACTION_CLEAR_REWARDS = "res://scripts/actions/rewards/ActionClearRewards.gd"

# shop
const ACTION_SHOP_PURCHASE_ITEMS: String = "res://scripts/actions/shop_actions/ActionShopPurchaseItems.gd"
const ACTION_SHOP_POPULATE_ITEMS: String = "res://scripts/actions/shop_actions/ActionShopPopulateItems.gd"

# enemy actions
const ACTION_CYCLE_ENEMY_INTENT: String = "res://scripts/actions/enemy_actions/ActionCycleEnemyIntent.gd"

# artifact actions
const ACTION_INCREASE_ARTIFACT_CHARGE: String = "res://scripts/actions/artifact_actions/ActionIncreaseArtifactCharge.gd"

# pick card actions, used to select cards and typically apply cardset child actions
const ACTION_PICK_CARDS: String = "res://scripts/actions/pick_card_actions/ActionPickCards.gd"
const ACTION_PICK_UPGRADE_CARDS: String = "res://scripts/actions/pick_card_actions/ActionPickUpgradeCards.gd"
const ACTION_CREATE_CARDS: String = "res://scripts/actions/pick_card_actions/ActionCreateCards.gd"

# cardsset actions
const ACTION_IMPROVE_CARD_VALUES: String = "res://scripts/actions/cardset_actions/ActionImproveCardValues.gd"
const ACTION_DISCARD_CARDS: String = "res://scripts/actions/cardset_actions/ActionDiscardCards.gd"
const ACTION_EXHAUST_CARDS: String = "res://scripts/actions/cardset_actions/ActionExhaustCards.gd"
const ACTION_BANISH_CARDS: String = "res://scripts/actions/cardset_actions/ActionBanishCards.gd"
const ACTION_MOVE_CARDS_TO_LIMBO: String = "res://scripts/actions/cardset_actions/ActionMoveCardsToLimbo.gd"
const ACTION_ADD_CARDS_TO_HAND: String = "res://scripts/actions/cardset_actions/ActionAddCardsToHand.gd"
const ACTION_CHANGE_CARD_ENERGIES: String = "res://scripts/actions/cardset_actions/ActionChangeCardEnergies.gd"
const ACTION_CHANGE_CARD_PROPERTIES: String = "res://scripts/actions/cardset_actions/ActionChangeCardProperties.gd"
const ACTION_RANDOMIZE_CARD_ENERGIES: String = "res://scripts/actions/cardset_actions/ActionRandomizeCardEnergies.gd"
const ACTION_TRANSFORM_CARDS: String = "res://scripts/actions/cardset_actions/ActionTransformCards.gd"
const ACTION_ADD_CARDS_TO_DRAW: String = "res://scripts/actions/cardset_actions/ActionAddCardsToDraw.gd"
const ACTION_ADD_CARDS_TO_DECK: String = "res://scripts/actions/cardset_actions/ActionAddCardsToDeck.gd"
const ACTION_REMOVE_CARDS_FROM_DECK: String = "res://scripts/actions/cardset_actions/ActionRemoveCardsFromDeck.gd"
const ACTION_RETAIN_CARDS: String = "res://scripts/actions/cardset_actions/ActionRetainCards.gd"
const ACTION_PLAY_CARDS: String = "res://scripts/actions/cardset_actions/ActionPlayCards.gd"
const ACTION_ATTACH_CARDS_ONTO_ENEMY = "res://scripts/actions/cardset_actions/ActionAttachCardsOntoEnemy.gd"
const ACTION_UPGRADE_CARDS: String = "res://scripts/actions/cardset_actions/ActionUpgradeCards.gd"
#endregion

#region Validators
# card property validators
const VALIDATOR_CARD_COLOR: String = "res://scripts/validators/card/ValidatorCardColor.gd"
const VALIDATOR_CARD_TAG: String = "res://scripts/validators/card/ValidatorCardTag.gd"
const VALIDATOR_CARD_DRAFTABLE = "res://scripts/validators/card/ValidatorCardDraftable.gd"
const VALIDATOR_CARD_ENERGY_COST: String = "res://scripts/validators/card/ValidatorCardEnergyCost.gd"
const VALIDATOR_CARD_ID: String = "res://scripts/validators/card/ValidatorCardID.gd"
const VALIDATOR_CARD_LOCATION: String = "res://scripts/validators/card/ValidatorCardLocation.gd"
const VALIDATOR_CARD_PROPERTIES: String = "res://scripts/validators/card/ValidatorCardProperties.gd"
const VALIDATOR_CARD_RARITY: String = "res://scripts/validators/card/ValidatorCardRarity.gd"
const VALIDATOR_CARD_REMOVEABLE_FROM_DECK: String = "res://scripts/validators/card/ValidatorCardRemovableFromDeck.gd"
const VALIDATOR_CARD_TRANSFORMABLE_FROM_DECK: String = "res://scripts/validators/card/ValidatorCardTransformableFromDeck.gd"
const VALIDATOR_CARD_TYPE: String = "res://scripts/validators/card/ValidatorCardType.gd"
const VALIDATOR_CARD_UPGRADEABLE: String = "res://scripts/validators/card/ValidatorCardUpgradeable.gd"

# card play validators
const VALIDATOR_CARD_PLAY_ENEMY_ATTACKING: String = "res://scripts/validators/card_plays/ValidatorCardPlayEnemyAttacking.gd"
const VALIDATOR_CARD_PLAY_ENERGY_INPUT: String = "res://scripts/validators/card_plays/ValidatorCardPlayEnergyInput.gd"
const VALIDATOR_CARD_PLAY_IS_DUPLICATED: String = "res://scripts/validators/card_plays/ValidatorCardPlayIsDuplicated.gd"

# deck/pile validators
const VALIDATOR_DECK_HAS_REMOVEABLE_CARD: String = "res://scripts/validators/deck/ValidatorDeckHasRemovableCard.gd"
const VALIDATOR_DECK_HAS_UPGRADEABLE_CARD: String = "res://scripts/validators/deck/ValidatorDeckHasUpgradeableCard.gd"
const VALIDATOR_PILE_SIZE: String = "res://scripts/validators/deck/ValidatorPileSize.gd"

# hand validators
const VALIDATOR_CARD_TYPE_ADJACENT_IN_HAND: String = "res://scripts/validators/hand/ValidatorCardTypeAdjacentInHand.gd"
const VALIDATOR_CARD_ID_ADJACENT_IN_HAND: String = "res://scripts/validators/hand/ValidatorCardIDAdjacentInHand.gd"
const VALIDATOR_CARD_POSITION_IN_HAND: String = "res://scripts/validators/hand/ValidatorCardPositionInHand.gd"
const VALIDATOR_CARD_TYPE_IN_HAND: String = "res://scripts/validators/hand/ValidatorCardTypeInHand.gd"

# combat validators
const VALIDATOR_COMBAT_STATS: String = "res://scripts/validators/ValidatorCombatStats.gd"
const VALIDATOR_IN_COMBAT: String = "res://scripts/validators/ValidatorInCombat.gd"
const VALIDATOR_PLAYER_TURN: String = "res://scripts/validators/ValidatorPlayerTurn.gd"
const VALIDATOR_TURN_COUNT: String = "res://scripts/validators/ValidatorTurnCount.gd"

# enemy validators
const VALIDATOR_ENEMY_TYPE: String = "res://scripts/validators/ValidatorEnemyType.gd"
const VALIDATOR_ENEMY_ATTACKING: String = "res://scripts/validators/ValidatorEnemyAttacking.gd"

const VALIDATOR_HAS_RELIC: String = "res://scripts/validators/ValidatorHasRelic.gd"
const VALIDATOR_LOCATION_TYPE: String = "res://scripts/validators/ValidatorLocationType.gd"
const VALIDATOR_MONEY: String = "res://scripts/validators/ValidatorMoney.gd"
const VALIDATOR_PLAYER_HEALTH: String = "res://scripts/validators/ValidatorPlayerHealth.gd"
const VALIDATOR_RNG: String = "res://scripts/validators/ValidatorRNG.gd"

#endregion

#region Card Listeners
const LISTENER_CARD_COST_MODIFIER: String = "res://scripts/card_listeners/ListenerCardCostModifier.gd"
const LISTENER_CARD_VALUE_MODIFIER = "res://scripts/card_listeners/ListenerCardValueModifier.gd"
#endregion

#region Interceptors
const INTERCEPTOR_DAMAGE_INCREASE: String = "res://scripts/action_interceptors/InterceptorDamageIncrease.gd"
const INTERCEPTOR_WEAKEN: String = "res://scripts/action_interceptors/InterceptorWeaken.gd"
const INTERCEPTOR_VULNERABLE: String = "res://scripts/action_interceptors/InterceptorVulnerable.gd"
const INTERCEPTOR_NEGATE_DAMAGE: String = "res://scripts/action_interceptors/InterceptorNegateDamage.gd"
const INTERCEPTOR_PRESERVE_BLOCK: String = "res://scripts/action_interceptors/InterceptorPreserveBlock.gd"
const INTERCEPTOR_NEGATE_DEBUFF: String = "res://scripts/action_interceptors/InterceptorNegateDebuff.gd"
# duplicating
const INTERCEPTOR_DUPLICATE_CARD_PLAYS: String = "res://scripts/action_interceptors/InterceptorDuplicateCardPlays.gd"
const INTERCEPTOR_DUPLICATE_ATTACKS: String = "res://scripts/action_interceptors/InterceptorDuplicateAttacks.gd"
#endregion
