extends RefCounted

# {"name": "external_host_removal_audit"}

## Contract test: verifies that external-host production artifacts have been removed.
## This test is RED (fails) before task-9 deletion, GREEN after.
## It checks the task-9 deletion guard only: product directories plus plugin runtime references.

const _allowed_test_scaffolding := [
	"tests/godot_plugin_harness",
	"tests/godot_plugin_harness_fixture",
]

var _audit_results: Array[Dictionary] = []


func run_case(_tree: SceneTree) -> Dictionary:
	_audit_results.clear()
	var repo_root := _get_repo_root_absolute()

	# Category 1: central_server/ directory must not exist
	if DirAccess.dir_exists_absolute(_repo_path(repo_root, "central_server")):
		_audit_results.append({
		"category": "directory",
		"target": "central_server/",
		"status": "FOUND",
		"required_action": "delete entire directory"
	})

	# Category 2: host_shared/ directory must not exist
	if DirAccess.dir_exists_absolute(_repo_path(repo_root, "host_shared")):
		_audit_results.append({
		"category": "directory",
		"target": "host_shared/",
		"status": "FOUND",
		"required_action": "delete entire directory"
	})

	# Category 3: tests/host_contracts/ directory must not exist
	if DirAccess.dir_exists_absolute(_repo_path(repo_root, "tests/host_contracts")):
		_audit_results.append({
		"category": "directory",
		"target": "tests/host_contracts/",
		"status": "FOUND",
		"required_action": "delete entire directory"
	})

	# Category 4: External host launch/attach/configuration references in plugin runtime
	var plugin_runtime_issues := _check_plugin_runtime_references()
	_audit_results.append_array(plugin_runtime_issues)

	# Build the failure message listing all found artifacts
	if _audit_results.size() > 0:
		var lines: Array[String] = []
		lines.append("EXTERNAL HOST ARTIFACTS STILL PRESENT — deletion required:")
		for issue in _audit_results:
			lines.append("  [%s] %s: %s" % [str(issue.get("category", "")), str(issue.get("target", "")), str(issue.get("required_action", ""))])
		return {
			"name": "external_host_removal_audit",
			"success": false,
			"error": "\n".join(lines),
			"details": {
				"found_count": _audit_results.size(),
				"artifacts": _audit_results
			}
		}

	return {
		"name": "external_host_removal_audit",
		"success": true,
		"error": "",
		"details": {
			"found_count": 0,
			"artifacts": []
		}
	}


func cleanup_case(_tree: SceneTree) -> void:
	_audit_results.clear()


func _get_repo_root_absolute() -> String:
	var fixture_root := ProjectSettings.globalize_path("res://")
	return fixture_root.get_base_dir().get_base_dir().get_base_dir().simplify_path()


func _repo_path(repo_root: String, relative_path: String) -> String:
	return repo_root.path_join(relative_path).simplify_path()


## Checks plugin runtime files for external host launch/attach/configuration references.
## Returns a list of issues found.
func _check_plugin_runtime_references() -> Array[Dictionary]:
	var issues: Array[Dictionary] = []

	var search_terms := [
		"host_shared/",
		"tests/host_contracts/",
	]

	var repo_root := _get_repo_root_absolute()
	var plugin_files := _collect_audit_files(repo_root, [
		"addons/godot_dotnet_mcp/plugin/runtime",
		"addons/godot_dotnet_mcp/plugin/config",
		"docs",
		"scripts",
	])

	for plugin_file in plugin_files:
		if plugin_file.ends_with("scripts/validate_refactor_guardrails.ps1"):
			continue
		if not FileAccess.file_exists(plugin_file):
			continue
		var content := FileAccess.get_file_as_string(plugin_file)
		for term in search_terms:
			if term in content:
				issues.append({
					"category": "plugin_runtime_ref",
					"target": plugin_file,
					"found_term": term,
					"status": "FOUND",
					"required_action": "remove reference to '%s'" % term
				})

	return issues


func _collect_audit_files(repo_root: String, relative_roots: Array[String]) -> Array[String]:
	var collected: Array[String] = []
	for relative_root in relative_roots:
		var absolute_root := _repo_path(repo_root, relative_root)
		_collect_audit_files_recursive(absolute_root, collected)
	return collected


func _collect_audit_files_recursive(current_path: String, out_paths: Array[String]) -> void:
	var dir := DirAccess.open(current_path)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var entry := dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue

		var child_path := current_path.path_join(entry)
		if dir.current_is_dir():
			_collect_audit_files_recursive(child_path, out_paths)
			continue

		if entry.ends_with(".gd") or entry.ends_with(".md") or entry.ends_with(".ps1") or entry.ends_with(".yml") or entry.ends_with(".yaml"):
			out_paths.append(child_path)

	dir.list_dir_end()
