## ISSUE-017b — MapScene: render the StS-style tree map across N acts.
##
## Layout: each act renders as a vertical column of 6 floors, columns
## within an act spread horizontally. Edges drawn as line segments
## between source and destination node centers via _draw().
##
## Public API:
##   setup(map, current_id, visited_ids, locale)
##
## Signals:
##   node_selected(id: String)
extends Control

const MapNodeScene := preload("res://ui/map/map_node.tscn")
const MapGenScript := preload("res://core/map_generator.gd")

const ACT_GAP := 96
const FLOOR_GAP := 96
const COL_GAP := 96
const NODE_PAD := 32

signal node_selected(id: String)

@onready var _canvas: Control = $Scroll/Canvas
@onready var _scroll: ScrollContainer = $Scroll
@onready var _legend: Label = $Legend

var _map: Dictionary = {}
var _current_id: String = ""
var _visited: Dictionary = {}
var _generator: Object = null
var _node_positions: Dictionary = {}  # id → Vector2 (center)


func _ready() -> void:
	_generator = MapGenScript.new()
	_canvas.draw.connect(_on_canvas_draw)


func setup(map: Dictionary, current_id: String, visited_ids: Array, locale: String = "zh_CN") -> void:
	_map = map
	_current_id = current_id
	_visited.clear()
	for id in visited_ids:
		_visited[String(id)] = true
	_render(locale)


# ---------------------------------------------------------------------------
# Render
# ---------------------------------------------------------------------------

func _render(locale: String) -> void:
	for c in _canvas.get_children():
		c.queue_free()
	_node_positions.clear()
	_legend.text = _legend_text(locale)
	if _map.is_empty():
		return

	var reachable: Dictionary = {}
	if _current_id == "":
		# Run start: floor 0 of every act is the player's choice.
		for act in _map.get("acts", []):
			var floor0: Array = act["floors"][0]
			for cell in floor0:
				if cell != null:
					reachable[String(cell["id"])] = true
	else:
		for r_id in _generator.reachable_from(_map, _current_id):
			reachable[String(r_id)] = true

	var x_offset: int = 16
	var max_y: int = 16
	for act in _map.get("acts", []):
		var act_idx: int = int(act["act_index"])
		var act_label: Label = Label.new()
		act_label.text = _t("Act %d" % (act_idx + 1), locale)
		act_label.position = Vector2(x_offset, 0)
		_canvas.add_child(act_label)

		var floors: Array = act["floors"]
		for f in range(floors.size()):
			var row: Array = floors[f]
			for c in range(row.size()):
				var cell: Variant = row[c]
				if cell == null:
					continue
				var node_ui: Control = MapNodeScene.instantiate()
				_canvas.add_child(node_ui)
				var px: int = x_offset + c * COL_GAP
				var py: int = 32 + f * FLOOR_GAP
				node_ui.position = Vector2(px, py)

				var state: String = "unreachable"
				var id: String = String(cell["id"])
				if id == _current_id:
					state = "current"
				elif _visited.has(id):
					state = "visited"
				elif reachable.has(id):
					state = "reachable"
				node_ui.bind(cell, state, locale)
				node_ui.node_selected.connect(_on_node_selected)

				_node_positions[id] = node_ui.position + Vector2(32, 32)
				max_y = max(max_y, py + 64)
		x_offset += COLS_WIDTH() + ACT_GAP

	# Make sure the canvas is large enough so ScrollContainer scrolls.
	_canvas.custom_minimum_size = Vector2(x_offset + 32, max_y + 32)
	_canvas.queue_redraw()


func COLS_WIDTH() -> int:
	return MapGenScript.COLS_PER_FLOOR * COL_GAP


func _on_canvas_draw() -> void:
	if _map.is_empty():
		return
	var color := Color(0.7, 0.7, 0.8, 0.6)
	for act in _map.get("acts", []):
		for edge in act["edges"]:
			var a: Variant = _node_positions.get(String(edge[0]), null)
			var b: Variant = _node_positions.get(String(edge[1]), null)
			if a == null or b == null:
				continue
			_canvas.draw_line(a, b, color, 2.0, true)


func _on_node_selected(id: String) -> void:
	node_selected.emit(id)


func _t(s: String, locale: String) -> String:
	if locale != "zh_CN":
		return s
	# very narrow placeholder
	if s.begins_with("Act"):
		return "第 %s 章" % s.substr(4)
	return s


func _legend_text(locale: String) -> String:
	if locale == "zh_CN":
		return "战 战斗   精 精英   店 商店   营 营地   ? 事件   BOSS"
	return "N normal · E elite · S shop · C camp · ? event · B boss"
