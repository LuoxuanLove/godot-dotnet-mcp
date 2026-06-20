@tool
extends RefCounted

const UPDATE_REFS_BRANCHES_URL := "https://api.github.com/repos/LuoxuanLove/godot-dotnet-mcp/branches?per_page=100&page=1"
const UPDATE_REFS_RELEASES_URL := "https://api.github.com/repos/LuoxuanLove/godot-dotnet-mcp/releases?per_page=100&page=1"
const UPDATE_REFS_TAGS_URL := "https://api.github.com/repos/LuoxuanLove/godot-dotnet-mcp/tags?per_page=100&page=1"
const UPDATE_COMPARE_URL_TEMPLATE := "https://api.github.com/repos/LuoxuanLove/godot-dotnet-mcp/compare/%s...%s"
const UPDATE_BRANCH_REF_URL_TEMPLATE := "https://api.github.com/repos/LuoxuanLove/godot-dotnet-mcp/branches/%s"
const UPDATE_TARGET_PLUGIN_CFG_BRANCH_URL_TEMPLATE := "https://raw.githubusercontent.com/LuoxuanLove/godot-dotnet-mcp/refs/heads/%s/addons/godot_dotnet_mcp/plugin.cfg"
const UPDATE_TARGET_PLUGIN_CFG_TAG_URL_TEMPLATE := "https://raw.githubusercontent.com/LuoxuanLove/godot-dotnet-mcp/refs/tags/%s/addons/godot_dotnet_mcp/plugin.cfg"
const UPDATE_REFS_HTTP_TIMEOUT := 10.0
const UPDATE_REFS_BODY_SIZE_LIMIT := 16777216
const UPDATE_REFS_MAX_PAGES := 20
const UPDATE_SYNC_COMMIT_ARCHIVE_URL_PREFIX := "https://codeload.github.com/LuoxuanLove/godot-dotnet-mcp/zip/"
const UPDATE_SYNC_BRANCH_ARCHIVE_URL_PREFIX := "https://codeload.github.com/LuoxuanLove/godot-dotnet-mcp/zip/refs/heads/"
const UPDATE_SYNC_TAG_ARCHIVE_URL_PREFIX := "https://codeload.github.com/LuoxuanLove/godot-dotnet-mcp/zip/refs/tags/"
const UPDATE_SYNC_GITHUB_BRANCH_ARCHIVE_URL_PREFIX := "https://github.com/LuoxuanLove/godot-dotnet-mcp/archive/refs/heads/"
const UPDATE_SYNC_GITHUB_TAG_ARCHIVE_URL_PREFIX := "https://github.com/LuoxuanLove/godot-dotnet-mcp/archive/refs/tags/"
const UPDATE_SYNC_GITHUB_COMMIT_ARCHIVE_URL_PREFIX := "https://github.com/LuoxuanLove/godot-dotnet-mcp/archive/"
const UPDATE_SYNC_ARCHIVE_PATH := "user://godot_dotnet_mcp/update_branch.zip"
const UPDATE_SYNC_MARKER_PATH := "res://addons/godot_dotnet_mcp/.mcp_sync.json"
const UPDATE_SYNC_REPO_URL := "https://github.com/LuoxuanLove/godot-dotnet-mcp"
const UPDATE_SYNC_HTTP_TIMEOUT := 60.0
const UPDATE_SYNC_BODY_SIZE_LIMIT := 67108864
const UPDATE_SYNC_ADDON_ROOT := "res://addons/godot_dotnet_mcp"
const UPDATE_SYNC_EDITOR_REFRESH_TIMEOUT_MS := 15000


func get_refs_request_urls() -> Dictionary:
	return {
		"branches": UPDATE_REFS_BRANCHES_URL,
		"releases": UPDATE_REFS_RELEASES_URL,
		"tags": UPDATE_REFS_TAGS_URL
	}


func get_compare_url_template() -> String:
	return UPDATE_COMPARE_URL_TEMPLATE


func get_branch_ref_url_template() -> String:
	return UPDATE_BRANCH_REF_URL_TEMPLATE


func get_target_plugin_cfg_branch_url_template() -> String:
	return UPDATE_TARGET_PLUGIN_CFG_BRANCH_URL_TEMPLATE


func get_target_plugin_cfg_tag_url_template() -> String:
	return UPDATE_TARGET_PLUGIN_CFG_TAG_URL_TEMPLATE


func get_refs_http_timeout() -> float:
	return UPDATE_REFS_HTTP_TIMEOUT


func get_refs_body_size_limit() -> int:
	return UPDATE_REFS_BODY_SIZE_LIMIT


func get_refs_max_pages() -> int:
	return UPDATE_REFS_MAX_PAGES


func get_archive_url_prefixes() -> Dictionary:
	return {
		"commit_codeload": UPDATE_SYNC_COMMIT_ARCHIVE_URL_PREFIX,
		"commit_github": UPDATE_SYNC_GITHUB_COMMIT_ARCHIVE_URL_PREFIX,
		"branch_codeload": UPDATE_SYNC_BRANCH_ARCHIVE_URL_PREFIX,
		"branch_github": UPDATE_SYNC_GITHUB_BRANCH_ARCHIVE_URL_PREFIX,
		"tag_codeload": UPDATE_SYNC_TAG_ARCHIVE_URL_PREFIX,
		"tag_github": UPDATE_SYNC_GITHUB_TAG_ARCHIVE_URL_PREFIX
	}


func get_sync_archive_path() -> String:
	return UPDATE_SYNC_ARCHIVE_PATH


func get_sync_marker_path() -> String:
	return UPDATE_SYNC_MARKER_PATH


func get_sync_repo_url() -> String:
	return UPDATE_SYNC_REPO_URL


func get_sync_http_timeout() -> float:
	return UPDATE_SYNC_HTTP_TIMEOUT


func get_sync_body_size_limit() -> int:
	return UPDATE_SYNC_BODY_SIZE_LIMIT


func get_sync_addon_root() -> String:
	return UPDATE_SYNC_ADDON_ROOT


func get_sync_editor_refresh_timeout_ms() -> int:
	return UPDATE_SYNC_EDITOR_REFRESH_TIMEOUT_MS


func build_sync_marker_context() -> Dictionary:
	return {
		"source_repo_path": UPDATE_SYNC_REPO_URL,
		"target_addon_path": UPDATE_SYNC_ADDON_ROOT
	}
