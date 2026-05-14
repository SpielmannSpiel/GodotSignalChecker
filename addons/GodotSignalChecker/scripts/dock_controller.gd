@tool
extends Control

const SignalChecker: Resource = preload("res://addons/GodotSignalChecker/scripts/signal_checker.gd")
const Shared := preload("res://addons/GodotSignalChecker/scripts/shared.gd")

signal scan_finished(broken_count: int)

var result_header: Array = [
	"Signal",
	"From",
	"->",
	"To",
	"Missing method"
]
var last_results: Array = []
var editor_dock: EditorDock

@export var status: Label
@export var debug_check: CheckButton
@export var print_result_console_check: CheckButton
@export var tree: Tree

func _ready() -> void:
	# for some reasons this ready gets called twice
	# misuse the nil editor_dock that would cause problems
	# down the road to cancel the first call
	if not editor_dock:
		return

	custom_minimum_size = Vector2(0, 200)

	print_result_console_check.button_pressed = Shared.print_result
	print_result_console_check.toggled.connect(func(on: bool) -> void: Shared.print_result = on)

	debug_check.button_pressed = Shared.debug
	debug_check.toggled.connect(func(on: bool) -> void: Shared.debug = on)
	
	for i in range(result_header.size()):
		tree.set_column_title(i, result_header[i])

	tree.set_column_expand(2, false)
	
	rescan()


func rescan() -> void:
	status.text = "Scanning..."
	# Defer so the label paints before the (potentially slow) scan blocks the thread.
	await get_tree().process_frame
	_populate(SignalChecker.scan_project())


func _populate(results: Array) -> void:
	editor_dock.title = Shared.DOCK_TITLE

	if results.size() > 0:
		editor_dock.title += " (%d)" % results.size()
		editor_dock.icon_name = "NodeWarning"
		editor_dock.add_theme_color_override("font_color", Shared.ERROR_COLOR)
	else:
		editor_dock.icon_name = ""
		status.remove_theme_color_override("font_color")
	
	last_results = results
	tree.clear()
	
	var root: TreeItem = tree.create_item()

	var by_scene: Dictionary = {}
	for result in results:
		var key: String = result["scene_path"]
		if not by_scene.has(key):
			by_scene[key] = []
		by_scene[key].append(result)

	if Shared.print_result:
		print("  |  ".join(result_header))

	for scene_path in by_scene:
		var scene_item: TreeItem = tree.create_item(root)
		scene_item.set_text(0, scene_path)
		scene_item.set_selectable(1, false)
		scene_item.set_selectable(2, false)
		scene_item.set_metadata(0, scene_path)
		
		if Shared.print_result:
			print("Scene: ", scene_path)
		
		for result in by_scene[scene_path]:
			var wrong_parameter_count_message := " wrong parameter count" if result["wrong_parameter_count"] else ""
			var item: TreeItem = tree.create_item(scene_item)
			
			var field_entries = [
				String(result["signal_name"]),
				String(result["source_node_path"]),
				">",
				String(result["target_node_path"]),
				String(result["method_name"]) + wrong_parameter_count_message
			]
			
			var row_format = "%s  |  %s -%s %s  |  %s"
			for i in range(field_entries.size()):
				item.set_text(i, field_entries[i])
				if Shared.print_result:
					print(row_format % field_entries)
			
			item.set_metadata(0, scene_path)


	if results.is_empty():
		status.text = "No broken connections."
		status.remove_theme_color_override("font_color")
	else:
		status.text = "%d broken connection(s) across %d scene(s)." % [results.size(), by_scene.size()]
		status.add_theme_color_override("font_color", Shared.ERROR_COLOR)
		
	scan_finished.emit(results.size())


func _on_item_activated() -> void:
	var item: TreeItem = tree.get_selected()
	if item == null:
		return
	
	var path: Variant = item.get_metadata(0)
	if typeof(path) == TYPE_STRING:
		EditorInterface.open_scene_from_path(path)
