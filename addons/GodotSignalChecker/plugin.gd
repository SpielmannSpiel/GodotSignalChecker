@tool
extends EditorPlugin

#const Dock := preload("res://addons/GodotSignalChecker/scripts/dock.gd")
const Shared := preload("res://addons/GodotSignalChecker/scripts/shared.gd")

var editor_dock: EditorDock

# Plugin initialization.
func _enter_tree():
	editor_dock = EditorDock.new()
	editor_dock.name = "SignalChecker"
	editor_dock.title = Shared.DOCK_TITLE
	editor_dock.force_show_icon = true
	#dock.dock_icon = preload("./dock_icon.png")
	editor_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	
	var dock_content = preload("res://addons/GodotSignalChecker/scenes/signal_checker_dock.tscn").instantiate()
	dock_content.editor_dock = editor_dock
	
	editor_dock.add_child(dock_content)
	add_dock(editor_dock)

# Plugin clean-up.
func _exit_tree():
	if not editor_dock:
		return
	
	remove_dock(editor_dock)
	editor_dock.queue_free()
	editor_dock = null
