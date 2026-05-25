## ISSUE-015a — Tests for shop transaction logic.
## Verifies affordability gating, collection mutation, heal cap, and
## inventory capacity blocking on trait buys.
extends GdUnitTestSuite

const Shop := preload("res://core/shop_state.gd")


# ---------------------------------------------------------------------------
# buy_card
# ---------------------------------------------------------------------------

func test_buy_card_appends_and_deducts_gold() -> void:
	var s: Object = Shop.new()
	var deck: Array = ["strike", "defend"]
	var result: Dictionary = s.buy_card(deck, "rite_of_ash", 80, 200)

	assert_bool(result["ok"]).is_true()
	assert_int(result["gold_after"]).is_equal(120)
	assert_array(deck).contains_exactly(["strike", "defend", "rite_of_ash"])


func test_buy_card_blocked_when_gold_insufficient() -> void:
	var s: Object = Shop.new()
	var deck: Array = ["strike"]
	var result: Dictionary = s.buy_card(deck, "rite_of_ash", 140, 100)

	assert_bool(result["ok"]).is_false()
	assert_str(result["reason"]).is_equal("insufficient_gold")
	assert_int(result["gold_after"]).is_equal(100)
	assert_array(deck).contains_exactly(["strike"])


# ---------------------------------------------------------------------------
# buy_trait
# ---------------------------------------------------------------------------

func test_buy_trait_appends_and_deducts_gold() -> void:
	var s: Object = Shop.new()
	var inv: Array = ["flame_brand"]
	var result: Dictionary = s.buy_trait(inv, "oil_slick", 70, 200)

	assert_bool(result["ok"]).is_true()
	assert_int(result["gold_after"]).is_equal(130)
	assert_array(inv).contains_exactly(["flame_brand", "oil_slick"])


func test_buy_trait_blocked_when_gold_insufficient() -> void:
	var s: Object = Shop.new()
	var inv: Array = []
	var result: Dictionary = s.buy_trait(inv, "oil_slick", 120, 50)

	assert_bool(result["ok"]).is_false()
	assert_str(result["reason"]).is_equal("insufficient_gold")
	assert_int(result["gold_after"]).is_equal(50)
	assert_int(inv.size()).is_equal(0)


func test_buy_trait_blocked_when_inventory_full() -> void:
	var s: Object = Shop.new()
	var inv: Array = ["a", "b", "c", "d", "e"]  # CAPACITY = 5
	var result: Dictionary = s.buy_trait(inv, "oil_slick", 40, 200)

	assert_bool(result["ok"]).is_false()
	assert_str(result["reason"]).is_equal("inventory_full")
	assert_int(result["gold_after"]).is_equal(200)
	assert_int(inv.size()).is_equal(5)


# ---------------------------------------------------------------------------
# buy_heal
# ---------------------------------------------------------------------------

func test_buy_heal_restores_30pct_of_max_hp() -> void:
	var s: Object = Shop.new()
	# 30% of 80 = 24
	var result: Dictionary = s.buy_heal(40, 80, 200)

	assert_bool(result["ok"]).is_true()
	assert_int(result["gold_after"]).is_equal(150)
	assert_int(result["player_hp_after"]).is_equal(64)
	assert_int(result["healed"]).is_equal(24)


func test_buy_heal_caps_at_max_hp() -> void:
	var s: Object = Shop.new()
	# 30% of 80 = 24, but only 5 hp missing
	var result: Dictionary = s.buy_heal(75, 80, 200)

	assert_bool(result["ok"]).is_true()
	assert_int(result["player_hp_after"]).is_equal(80)
	assert_int(result["healed"]).is_equal(5)


func test_buy_heal_blocked_when_already_full() -> void:
	var s: Object = Shop.new()
	var result: Dictionary = s.buy_heal(80, 80, 200)

	assert_bool(result["ok"]).is_false()
	assert_str(result["reason"]).is_equal("already_full_hp")
	assert_int(result["gold_after"]).is_equal(200)
	assert_int(result["player_hp_after"]).is_equal(80)


func test_buy_heal_blocked_when_gold_insufficient() -> void:
	var s: Object = Shop.new()
	var result: Dictionary = s.buy_heal(40, 80, 30)

	assert_bool(result["ok"]).is_false()
	assert_str(result["reason"]).is_equal("insufficient_gold")
	assert_int(result["gold_after"]).is_equal(30)
	assert_int(result["player_hp_after"]).is_equal(40)


# ---------------------------------------------------------------------------
# Invalid args
# ---------------------------------------------------------------------------

func test_buy_card_invalid_id_fails_safely() -> void:
	var s: Object = Shop.new()
	var deck: Array = []
	var result: Dictionary = s.buy_card(deck, "", 50, 200)
	assert_bool(result["ok"]).is_false()
	assert_int(deck.size()).is_equal(0)


func test_buy_trait_invalid_id_fails_safely() -> void:
	var s: Object = Shop.new()
	var inv: Array = []
	var result: Dictionary = s.buy_trait(inv, "", 40, 200)
	assert_bool(result["ok"]).is_false()
	assert_int(inv.size()).is_equal(0)
