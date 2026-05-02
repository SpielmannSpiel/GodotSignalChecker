@tool
extends RefCounted

const Shared := preload("res://addons/GodotSignalChecker/scripts/shared.gd")


static func scan_project() -> Array:
	# Scans every .tscn in the project and returns a list of broken connections.
	var results: Array = []
	for path in _collect_scenes("res://"):
		results.append_array(_check_scene(path))
	
	return results


static func _collect_scenes(root: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(root)
	
	if dir == null:
		return out
	
	dir.list_dir_begin()
	var name := dir.get_next()
	
	while name != "":
		# Skip hidden dirs (.godot, .git, ...) and our own addons folder
		if not name.begins_with("."):
			var full := root.path_join(name)
			if dir.current_is_dir():
				# ignore any folder that has a .gdignore inside it
				if FileAccess.file_exists(full.path_join(".gdignore")):
					pass
				else:
					out.append_array(_collect_scenes(full))
			
			elif name.ends_with(".tscn"):
				out.append(full)
		
		name = dir.get_next()
	
	dir.list_dir_end()
	return out


static func _check_scene(path: String) -> Array:
	var results: Array = []
	var pack := load(path) as PackedScene
	
	if pack == null:
		return results

	var state := pack.get_state()
	var conn_count := state.get_connection_count()
	if conn_count == 0:
		return results

	var root := pack.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if root == null:
		return results

	for i in conn_count:
		var dst_path: NodePath = state.get_connection_target(i)
		var method: StringName = state.get_connection_method(i)
		var target := root.get_node_or_null(dst_path)
		
		if target == null:
			# Target node itself is missing - still a broken connection.
			results.append(_make(path, state, i))
			continue
		
		if not _target_has_method(target, method):
			results.append(_make(path, state, i))

	root.queue_free()
	return results


static func _target_has_method(target: Node, method: StringName) -> bool:
	var script := target.get_script() as Script
	var result: bool
		
	result = target.has_method(method)
	var script_path := script.resource_path if script != null else "<none>"
	Shared.debug_log("%s.%s  script=%s  -> %s" % [target.name, method, script_path, "OK" if result else "MISSING"])
	return result


static func _make(path: String, state: SceneState, i: int) -> Dictionary:
	return {
		"scene_path": path,
		"source_node_path": state.get_connection_source(i),
		"signal_name": state.get_connection_signal(i),
		"target_node_path": state.get_connection_target(i),
		"method_name": state.get_connection_method(i),
	}
