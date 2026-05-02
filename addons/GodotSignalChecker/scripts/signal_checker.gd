@tool
extends RefCounted

const Shared := preload("res://addons/GodotSignalChecker/scripts/shared.gd")


# Scans every .tscn in the project and returns a list of broken connections.
#
# Each result is a Dictionary with:
#   scene_path:        String     - res:// path to the scene
#   source_node_path:  NodePath   - emitter, relative to the scene root
#   signal_name:       StringName
#   target_node_path:  NodePath   - receiver, relative to the scene root
#   method_name:       StringName - the method that should exist but doesn't

# Cache of .cs path -> Dictionary[method_name, true]. Cleared per scan.
static var _cs_cache: Dictionary = {}


static func scan_project() -> Array:
	_cs_cache.clear()
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
	# C# methods can't be verified through has_method() or
	# get_script_method_list() in the editor - both surface phantom entries
	# for stored connection targets, so a renamed receiver still reports as
	# present. For C# we go straight to a text scan of the .cs source.
	var script := target.get_script() as Script
	var result: bool
	
	#if script != null and _has_csharp_in_chain(script):
	#	result = _csharp_chain_has_method(script, method)
	#else:
	#	result = target.has_method(method)
	
	result = target.has_method(method)
	var script_path := script.resource_path if script != null else "<none>"
	Shared.debug_log("%s.%s  script=%s  -> %s" % [target.name, method, script_path, "OK" if result else "MISSING"])
	return result


static func _has_csharp_in_chain(script: Script) -> bool:
	var s := script
	
	while s != null:
		if s.get_class() == "CSharpScript":
			return true
		s = s.get_base_script()
	
	return false


static func _csharp_chain_has_method(script: Script, method: StringName) -> bool:
	var s := script
	
	while s != null:
		if s.get_class() == "CSharpScript":
			if _csharp_source_has_method(s.resource_path, method):
				return true
		s = s.get_base_script()
	
	return false


static func _csharp_source_has_method(script_path: String, method: StringName) -> bool:
	if not _cs_cache.has(script_path):
		_cs_cache[script_path] = _scan_csharp_methods(script_path)
		Shared.debug_log("parsed %s -> %s" % [script_path, _cs_cache[script_path].keys()])
	
	return _cs_cache[script_path].has(String(method))


static func _scan_csharp_methods(path: String) -> Dictionary:
	var methods: Dictionary = {}
	if path.is_empty() or not FileAccess.file_exists(path):
		return methods
	
	var src := FileAccess.get_file_as_string(path)
	if src.is_empty():
		return methods
	
	# Anchor on access-modifier word boundary, then lazy-skip return type
	# / modifiers / generics until we hit an identifier directly followed
	# by `(`. The char class blocks `=`, `;`, `{`, `}` so we don't span
	# into another statement (e.g. property initializers).
	var re := RegEx.new()
	if re.compile("\\b(?:public|private|protected|internal)\\s+[\\w<>?,\\[\\]\\s]*?(\\w+)\\s*\\(") != OK:
		push_warning("SignalChecker: failed to compile C# method regex")
		return methods
	
	for m in re.search_all(src):
		methods[m.get_string(1)] = true
	
	return methods


static func _make(path: String, state: SceneState, i: int) -> Dictionary:
	return {
		"scene_path": path,
		"source_node_path": state.get_connection_source(i),
		"signal_name": state.get_connection_signal(i),
		"target_node_path": state.get_connection_target(i),
		"method_name": state.get_connection_method(i),
	}
