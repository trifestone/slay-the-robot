## ISSUE-009b — TraitIcon control: a single 48×48 trait slot.
## Renders icon placeholder + optional lock badge for slot[0].
## Designer fills in real icon textures later (PRD §A5 art pass).
extends Control

const SLOT_SIZE := Vector2(48, 48)

@onready var _bg: ColorRect      = $Bg
@onready var _label: Label       = $Label
@onready var _lock_badge: Label  = $LockBadge

var _trait: Resource = null
var _locked: bool = false


func _ready() -> void:
	custom_minimum_size = SLOT_SIZE
	# bind() may have run before the node entered the tree (e.g. inventory_grid
	# constructs and binds children before adding them); apply the staged data now.
	_refresh()


## Bind a Trait Resource (or null for empty slot) and a locked flag.
func bind(t: Resource, locked: bool = false) -> void:
	_trait = t
	_locked = locked
	if is_inside_tree():
		_refresh()


func _refresh() -> void:
	if _bg == null or _label == null or _lock_badge == null:
		# Pre-_ready() bind — the deferred call from _ready() will pick it up.
		return
	if _trait == null:
		# Empty: muted "+" placeholder
		_bg.color = Color(0.2, 0.2, 0.2, 0.5)
		_label.text = "+"
		_label.modulate = Color(1, 1, 1, 0.4)
	else:
		# Color-code by school (placeholder until real icons land)
		_bg.color = _school_color(_trait.axis_school)
		_label.text = _short_id(_trait.id)
		_label.modulate = Color(1, 1, 1, 1)
	_lock_badge.visible = _locked


func _school_color(school: int) -> Color:
	match school:
		0: return Color(0.85, 0.35, 0.20)  # Fire — red-orange
		1: return Color(0.45, 0.65, 0.30)  # Decay — sickly green
		2: return Color(0.55, 0.65, 0.85)  # Moon — pale blue
		3: return Color(0.65, 0.65, 0.70)  # Iron — steel gray
		4: return Color(0.85, 0.80, 0.65)  # Bone — bone white
		5: return Color(0.45, 0.30, 0.55)  # Void — deep purple
		_: return Color(0.30, 0.30, 0.30)


func _short_id(id: String) -> String:
	# 2-3 letter abbreviation, deterministic from id
	if id.length() <= 3:
		return id.to_upper()
	var parts: PackedStringArray = id.split("_")
	if parts.size() >= 2:
		return (parts[0].substr(0, 1) + parts[1].substr(0, 2)).to_upper()
	return id.substr(0, 3).to_upper()
