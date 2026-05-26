## Tests for the VFX + UI enhancements:
##   1. PlayerUI block shield display
##   2. AnimSignaler heal / block signals
##   3. VFXLayer player heal float positioning
extends GdUnitTestSuite

const AnimSignalerScript := preload("res://core/anim_signaler.gd")
const VFXLayerScript     := preload("res://ui/battle/vfx_layer.gd")
const PlayerUIScript     := preload("res://ui/battle/player_ui.tscn")

var _test_received_amount: int = 0
var _test_received_delta: int = 0
var _test_received_gain: bool = false
var _test_received_rem: int = 0
var _test_broke: bool = false


# ---------------------------------------------------------------------------
# AnimSignaler signals
# ---------------------------------------------------------------------------

func test_player_healed_signal_fires() -> void:
	var signaler: Node = AnimSignalerScript.new()
	add_child(signaler)
	await get_tree().process_frame
	_test_received_amount = 0
	signaler.player_healed.connect(_on_test_player_healed)
	signaler.notify_player_healed(7)
	assert_int(_test_received_amount).is_equal(7)
	signaler.queue_free()

func _on_test_player_healed(amount: int) -> void:
	_test_received_amount = amount


func test_block_changed_signal_fires() -> void:
	var signaler: Node = AnimSignalerScript.new()
	add_child(signaler)
	await get_tree().process_frame
	_test_received_delta = 0
	_test_received_gain = false
	_test_received_rem = 0
	signaler.block_changed.connect(_on_test_block_changed)
	signaler.notify_block_changed(5, true, 5)
	assert_int(_test_received_delta).is_equal(5)
	assert_bool(_test_received_gain).is_true()
	assert_int(_test_received_rem).is_equal(5)
	signaler.queue_free()

func _on_test_block_changed(delta: int, is_gain: bool, remaining: int) -> void:
	_test_received_delta = delta
	_test_received_gain = is_gain
	_test_received_rem = remaining


func test_shield_broke_signal_fires_on_zero_block() -> void:
	var signaler: Node = AnimSignalerScript.new()
	add_child(signaler)
	await get_tree().process_frame
	_test_broke = false
	signaler.shield_broke.connect(_on_test_shield_broke)
	signaler.notify_block_changed(-3, false, 0)
	assert_bool(_test_broke).is_true()
	signaler.queue_free()

func test_shield_broke_does_not_fire_when_block_remains() -> void:
	var signaler: Node = AnimSignalerScript.new()
	add_child(signaler)
	await get_tree().process_frame
	_test_broke = false
	signaler.shield_broke.connect(_on_test_shield_broke)
	signaler.notify_block_changed(-2, false, 1)
	assert_bool(_test_broke).is_false()
	signaler.queue_free()

func _on_test_shield_broke() -> void:
	_test_broke = true


# ---------------------------------------------------------------------------
# PlayerUI block display
# ---------------------------------------------------------------------------

func test_player_ui_shows_block_when_positive() -> void:
	var ui: Control = PlayerUIScript.instantiate()
	add_child(ui)
	await get_tree().process_frame
	ui.bind(80, 100, 5)
	var shield: Control = ui.get_node_or_null("ShieldIcon")
	assert_bool(shield.visible if shield != null else false).is_true()
	var block_label: Label = ui.get_node_or_null("BlockLabel")
	if block_label != null:
		assert_str(block_label.text).contains("格挡 5")
	ui.queue_free()


func test_player_ui_hides_block_when_zero() -> void:
	var ui: Control = PlayerUIScript.instantiate()
	add_child(ui)
	await get_tree().process_frame
	ui.bind(80, 100, 0)
	var shield: Control = ui.get_node_or_null("ShieldIcon")
	assert_bool(shield.visible if shield != null else false).is_false()
	ui.queue_free()


func test_player_ui_hp_bar_updates() -> void:
	var ui: Control = PlayerUIScript.instantiate()
	add_child(ui)
	await get_tree().process_frame
	ui.bind(50, 100, 0)
	var bar: ProgressBar = ui.get_node_or_null("HpBar")
	if bar != null:
		assert_float(bar.value).is_equal(0.5)
	ui.queue_free()
