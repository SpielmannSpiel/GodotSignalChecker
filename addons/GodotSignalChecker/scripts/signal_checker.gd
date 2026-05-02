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
		# Skip hidden dirs (.godot, .git, ...)
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
	var connection_count := state.get_connection_count()
	if connection_count == 0:
		return results

	var root := pack.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if root == null:
		return results

	for i in connection_count:
		var dst_path: NodePath = state.get_connection_target(i)
		var method: StringName = state.get_connection_method(i)
		var target := root.get_node_or_null(dst_path)
		
		if target == null:
			# Target node itself is missing - still a broken connection.
			results.append(_make_report_entry(path, state, i, false))
			continue
		
		if not _target_has_method(target, method):
			results.append(_make_report_entry(path, state, i, false))
		
		# TODO: make parameter count work
		#else:
		#	var source_node: Node = root.get_node_or_null(state.get_node_path(i))
		#	if not _method_params_equal(source_node, target, method):
		#		results.append(_make_report_entry(path, state, i, true))

	root.queue_free()
	return results


static func _method_params_equal(source: Node, target: Node, method_name: StringName) -> bool:
	# doesnt work, yet
	var source_script := source.get_script() as Script
	var target_script := target.get_script() as Script
	
	if source_script != null:
		for m in source_script.get_script_method_list():
			if m["name"] == method_name:
				print(m["args"])
				print(m["args"].size())

	if target_script != null:
		for m in target_script.get_script_method_list():
			if m["name"] == method_name:
				print(m["args"])
				print(m["args"].size())

	# these always return 0
	var source_arguments_count: int = source.get_method_argument_count(method_name)
	var target_arguments_count: int = target.get_method_argument_count(method_name)
	
	var target_script_path := target_script.resource_path if target_script != null else "<none>"
	Shared.debug_log(
		"%s.%s  script=%s -> parameter count %d/%d %s" % [
			target.name,
			method_name,
			target_script_path,
			source_arguments_count,
			target_arguments_count,
			"OK" if source_arguments_count == target_arguments_count else "WRONG PARAMETER COUNT"
		]
	)
	return source_arguments_count == target_arguments_count


static func _target_has_method(target: Node, method: StringName) -> bool:
	var script := target.get_script() as Script
	var result: bool
		
	result = target.has_method(method)

	var script_path := script.resource_path if script != null else "<none>"
	Shared.debug_log("%s.%s  script=%s -> %s" % [target.name, method, script_path, "OK" if result else "MISSING"])
	return result


static func _make_report_entry(path: String, state: SceneState, idx: int, wrong_parameter_count: bool) -> Dictionary:
	return {
		"scene_path": path,
		"source_node_path": state.get_connection_source(idx),
		"signal_name": state.get_connection_signal(idx),
		"target_node_path": state.get_connection_target(idx),
		"method_name": state.get_connection_method(idx),
		"wrong_parameter_count": wrong_parameter_count
	}
