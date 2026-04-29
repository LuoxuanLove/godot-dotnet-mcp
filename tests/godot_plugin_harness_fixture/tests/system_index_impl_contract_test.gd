extends RefCounted

const IndexImplScript = preload("res://addons/godot_dotnet_mcp/tools/system/impl_index.gd")
const FIXTURE_ROOT := "res://tests/index_contract_fixture"


class FakeBridge extends RefCounted:
	var script_paths: Array[String] = []
	var scene_paths: Array[String] = []

	func collect_files(pattern: String) -> Array:
		match pattern:
			"*.gd":
				return script_paths.duplicate()
			"*.cs":
				return []
			"*.tscn":
				return scene_paths.duplicate()
			"*.tres", "*.res":
				return []
			_:
				return []

	func call_atomic(tool_name: String, args: Dictionary) -> Dictionary:
		if tool_name == "script_inspect":
			var path := str(args.get("path", ""))
			if path.ends_with("Player.gd"):
				return success({
					"language": "gdscript",
					"class_name": "Player",
					"base_type": "Node2D",
					"namespace": "",
					"method_count": 2,
					"export_count": 1
				})
			if path.ends_with("Boss.gd"):
				return success({
					"language": "gdscript",
					"class_name": "Boss",
					"base_type": "Node2D",
					"namespace": "",
					"method_count": 3,
					"export_count": 0
				})
		elif tool_name == "resource_query":
			var path := str(args.get("path", ""))
			if path.ends_with("Main.tscn"):
				return success({
					"dependencies": ["%s/Hud.tscn" % FIXTURE_ROOT]
				})
			return success({
				"dependencies": []
			})

		return error("Unsupported fake bridge call: %s" % tool_name)

	func extract_data(result: Dictionary) -> Dictionary:
		var data = result.get("data", {})
		return (data as Dictionary).duplicate(true) if data is Dictionary else {}

	func extract_array(result: Dictionary, key: String) -> Array:
		var data = result.get("data", {})
		if data is Dictionary:
			var value = (data as Dictionary).get(key, [])
			return (value as Array).duplicate(true) if value is Array else []
		return []

	func normalize_dependency_path(path: String) -> String:
		return path.strip_edges()

	func success(data) -> Dictionary:
		return {
			"success": true,
			"data": data
		}

	func error(message: String) -> Dictionary:
		return {
			"success": false,
			"error": "bridge_error",
			"message": message
		}


func run_case(_tree: SceneTree) -> Dictionary:
	_recreate_fixture_root()
	var player_path := "%s/Player.gd" % FIXTURE_ROOT
	var main_scene_path := "%s/Main.tscn" % FIXTURE_ROOT
	var hud_scene_path := "%s/Hud.tscn" % FIXTURE_ROOT
	_write_text_file(player_path, "extends Node2D\nclass_name Player\n")
	_write_text_file(main_scene_path, "[gd_scene format=3]\n[ext_resource type=\"PackedScene\" path=\"res://tests/index_contract_fixture/Hud.tscn\" id=\"1\"]\n")
	_write_text_file(hud_scene_path, "[gd_scene format=3]\n")

	var fake_bridge := FakeBridge.new()
	fake_bridge.script_paths = [player_path]
	fake_bridge.scene_paths = [hud_scene_path, main_scene_path]

	var impl = IndexImplScript.new()
	impl.bridge = fake_bridge

	var search_player: Dictionary = impl.execute("project_symbol_search", {"symbol": "Player"})
	if not bool(search_player.get("success", false)):
		return _failure("project_symbol_search(Player) did not succeed.")
	var search_player_data = search_player.get("data", {})
	if not (search_player_data is Dictionary):
		return _failure("project_symbol_search(Player) did not return a dictionary payload.")
	if str((search_player_data as Dictionary).get("index_state", "")) != "built":
		return _failure("First project_symbol_search should build the index.")
	if int((search_player_data as Dictionary).get("exact_match_count", 0)) < 1:
		return _failure("project_symbol_search(Player) did not find the Player class.")

	var dependency_graph: Dictionary = impl.execute("scene_dependency_graph", {
		"root_scene": main_scene_path,
		"max_depth": 2
	})
	if not bool(dependency_graph.get("success", false)):
		return _failure("scene_dependency_graph(Main.tscn) did not succeed.")
	var dependency_data = dependency_graph.get("data", {})
	if not (dependency_data is Dictionary):
		return _failure("scene_dependency_graph(Main.tscn) did not return a dictionary payload.")
	var dependencies = (dependency_data as Dictionary).get("dependencies", {})
	if not (dependencies is Dictionary):
		return _failure("scene_dependency_graph(Main.tscn) did not return dependencies.")
	var root_dependencies = (dependencies as Dictionary).get(main_scene_path, [])
	if not (root_dependencies is Array) or not (root_dependencies as Array).has(hud_scene_path):
		return _failure("scene_dependency_graph(Main.tscn) did not preserve the Main -> Hud dependency.")

	var boss_path := "%s/Boss.gd" % FIXTURE_ROOT
	_write_text_file(boss_path, "extends Node2D\nclass_name Boss\n")
	fake_bridge.script_paths.append(boss_path)

	var search_boss: Dictionary = impl.execute("project_symbol_search", {"symbol": "Boss"})
	if not bool(search_boss.get("success", false)):
		return _failure("project_symbol_search(Boss) did not succeed after adding a new source.")
	var search_boss_data = search_boss.get("data", {})
	if not (search_boss_data is Dictionary):
		return _failure("project_symbol_search(Boss) did not return a dictionary payload.")
	if str((search_boss_data as Dictionary).get("index_state", "")) != "stale_refreshed":
		return _failure("Adding a new source file should force index_state=stale_refreshed.")
	if int((search_boss_data as Dictionary).get("exact_match_count", 0)) < 1:
		return _failure("project_symbol_search(Boss) did not find the newly added Boss class.")

	return {
		"name": "system_index_impl_contracts",
		"success": true,
		"error": "",
		"details": {
			"initial_index_state": str((search_player_data as Dictionary).get("index_state", "")),
			"refreshed_index_state": str((search_boss_data as Dictionary).get("index_state", "")),
			"dependency_count": int((dependency_data as Dictionary).get("count", 0))
		}
	}


func _recreate_fixture_root() -> void:
	var absolute_root := ProjectSettings.globalize_path(FIXTURE_ROOT)
	DirAccess.make_dir_recursive_absolute(absolute_root)


func _write_text_file(path: String, content: String) -> void:
	var absolute_path := ProjectSettings.globalize_path(path)
	DirAccess.make_dir_recursive_absolute(absolute_path.get_base_dir())
	var file := FileAccess.open(absolute_path, FileAccess.WRITE)
	file.store_string(content)
	file.close()


func _failure(message: String) -> Dictionary:
	return {
		"name": "system_index_impl_contracts",
		"success": false,
		"error": message
	}
