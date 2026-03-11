@tool
extends RefCounted

## 繁體中文翻譯

const TRANSLATIONS: Dictionary = {
	# Tab names
	"tab_server": "伺服器",
	"tab_tools": "工具",
	"tab_config": "設定",

	# Header
	"title": "Godot MCP Server",
	"dialog_title": "Godot MCP",
	"status_running": "執行中",
	"status_stopped": "已停止",

	# Server tab
	"server_status": "伺服器狀態",
	"server_state_label": "狀態：",
	"endpoint": "端點位址：",
	"connections": "連線數：",
	"active_connections": "活躍連線：",
	"total_requests": "總請求數：",
	"total_connections_short": "連線",
	"last_request": "最近請求：",
	"last_request_none": "尚無請求",
	"settings": "設定",
	"port": "連接埠：",
	"auto_start": "自動啟動",
	"debug_log": "除錯日誌",
	"btn_start": "啟動",
	"btn_restart": "重新啟動",
	"btn_stop": "停止",
	"btn_reload_plugin": "完整重新載入外掛",

	# About section
	"about": "關於",
	"author": "作者：",
	"wechat": "微信：",

	# Tools tab
	"tools_enabled": "工具：%d/%d 已啟用",
	"tool_profile": "預設：",
	"tool_profile_slim": "精簡",
	"tool_profile_default": "預設",
	"tool_profile_full": "完整",
	"tool_profile_slim_desc": "僅啟用 Godot.NET 專案中最常用的基礎檢查、編輯與外掛執行時工具。",
	"tool_profile_default_desc": "建議日常使用，保留基礎、外掛、玩法、視覺/動畫與介面相關工具。",
	"tool_profile_full_desc": "啟用目前註冊的全部工具分類。",
	"tool_profile_custom_desc": "自訂預設：%s",
	"tool_profile_modified_desc": "目前選擇已修改，可點擊「新增」儲存為自訂預設。",
	"tool_profile_save_title": "儲存自訂工具預設",
	"tool_profile_save_desc": "將目前工具選擇儲存為可重複使用的自訂預設檔案。",
	"tool_profile_name_placeholder": "輸入預設名稱",
	"tool_profile_name_required": "預設名稱不可為空",
	"tool_profile_saved": "預設已儲存：%s",
	"tool_profile_save_failed": "儲存預設失敗",
	"btn_expand_all": "全部展開",
	"btn_collapse_all": "全部摺疊",
	"btn_select_all": "全選",
	"btn_deselect_all": "全不選",
	"btn_add_profile": "新增",
	"btn_save_profile": "儲存",
	"tools_server_unavailable": "服務不可用，請檢查編輯器輸出中的腳本載入錯誤。",
	"tools_load_errors": "有 %d 個工具分類因腳本載入失敗被略過，請查看編輯器輸出。",

	# Tool categories - Core
	"cat_scene": "場景",
	"cat_node": "節點",
	"cat_script": "腳本",
	"cat_resource": "資源",
	"cat_filesystem": "檔案系統",
	"cat_project": "專案",
	"cat_editor": "編輯器",
	"cat_plugin": "外掛執行時",
	"cat_debug": "除錯",
	"cat_animation": "動畫",

	# Tool categories - Visual
	"cat_material": "材質",
	"cat_shader": "著色器",
	"cat_lighting": "燈光",
	"cat_particle": "粒子",

	# Tool categories - 2D
	"cat_tilemap": "圖塊地圖",
	"cat_geometry": "幾何體",

	# Tool categories - Gameplay
	"cat_physics": "物理",
	"cat_navigation": "導航",
	"cat_audio": "音訊",

	# Tool categories - Utilities
	"cat_ui": "使用者介面",
	"cat_signal": "訊號",
	"cat_group": "群組",
	"domain_core": "核心",
	"domain_plugin": "外掛",
	"domain_visual": "視覺",
	"domain_gameplay": "玩法",
	"domain_interface": "介面",
	"domain_other": "其他",

	# Config tab - IDE section
	"ide_config": "IDE 一鍵設定",
	"ide_config_desc": "點擊後自動寫入設定檔，重新啟動客戶端生效",
	"btn_one_click": "一鍵設定",
	"btn_copy": "複製",

	# Config tab - CLI section
	"cli_config": "CLI 命令列設定",
	"cli_config_desc": "複製命令並在終端機中執行",
	"config_scope": "設定範圍：",
	"scope_user": "使用者級（全域）",
	"scope_project": "專案級（僅目前專案）",
	"btn_copy_cmd": "複製命令",

	# Messages
	"msg_config_success": "%s 設定成功！",
	"msg_config_failed": "設定失敗",
	"msg_copied": "%s 已複製到剪貼簿",
	"msg_parse_error": "設定解析失敗",
	"msg_dir_error": "無法建立目錄：",
	"msg_write_error": "無法寫入設定檔",

	# Language
	"language": "語言：",

	# ==================== Tool Descriptions ====================
	# Scene tools
	"tool_scene_bindings_name": "綁定檢查",
	"tool_scene_audit_name": "場景稽核",
	"tool_scene_management_name": "管理",
	"tool_scene_hierarchy_name": "階層",
	"tool_scene_run_name": "執行",
	"tool_scene_management_desc": "開啟、儲存、建立和管理場景",
	"tool_scene_hierarchy_desc": "取得場景樹結構和節點選擇",
	"tool_scene_run_desc": "在編輯器中執行和測試場景",
	"tool_scene_bindings_desc": "檢查場景中使用的導出腳本綁定",
	"tool_scene_audit_desc": "回報由導出綁定推導出的場景問題",

	# Node tools
	"tool_node_query_name": "查詢",
	"tool_node_lifecycle_name": "生命週期",
	"tool_node_transform_name": "變換",
	"tool_node_property_name": "屬性",
	"tool_node_hierarchy_name": "階層",
	"tool_node_signal_name": "訊號",
	"tool_node_group_name": "群組",
	"tool_node_process_name": "處理",
	"tool_node_metadata_name": "中繼資料",
	"tool_node_call_name": "呼叫",
	"tool_node_visibility_name": "可見性",
	"tool_node_physics_name": "物理",
	"tool_node_query_desc": "按名稱、類型或模式尋找並檢查節點",
	"tool_node_lifecycle_desc": "建立、刪除、複製和實例化節點",
	"tool_node_transform_desc": "修改位置、旋轉和縮放",
	"tool_node_property_desc": "取得和設定任意節點屬性",
	"tool_node_hierarchy_desc": "管理父子關係和節點順序",
	"tool_node_signal_desc": "連接、斷開和發射訊號",
	"tool_node_group_desc": "新增、移除和查詢節點群組",
	"tool_node_process_desc": "控制節點處理模式",
	"tool_node_metadata_desc": "取得和設定節點中繼資料",
	"tool_node_call_desc": "動態呼叫節點方法",
	"tool_node_visibility_desc": "控制節點可見性和圖層",
	"tool_node_physics_desc": "設定物理屬性",

	# Resource tools
	"tool_resource_query_name": "查詢",
	"tool_resource_manage_name": "管理",
	"tool_resource_texture_name": "紋理",
	"tool_resource_query_desc": "查找和檢查資源",
	"tool_resource_manage_desc": "載入、儲存和複製資源",
	"tool_resource_texture_desc": "管理紋理資源",

	# Project tools
	"tool_project_info_name": "資訊",
	"tool_project_settings_name": "設定",
	"tool_project_input_name": "輸入",
	"tool_project_autoload_name": "自動載入",
	"tool_project_info_desc": "取得專案資訊和路徑",
	"tool_project_settings_desc": "讀取和修改專案設定",
	"tool_project_input_desc": "管理輸入動作映射",
	"tool_project_autoload_desc": "管理自動載入單例",

	# Script tools
	"tool_script_read_name": "讀取",
	"tool_script_open_name": "開啟",
	"tool_script_inspect_name": "分析",
	"tool_script_symbols_name": "符號",
	"tool_script_exports_name": "導出",
	"tool_script_edit_gd_name": "編輯 GDScript",
	"tool_script_manage_desc": "建立、讀取和修改腳本",
	"tool_script_attach_desc": "附加或分離節點腳本",
	"tool_script_edit_desc": "新增函式、變數和訊號",
	"tool_script_open_desc": "在編輯器中開啟腳本",
	"tool_script_read_desc": "以純文字形式讀取腳本檔案",
	"tool_script_inspect_desc": "解析 GDScript 與 C# 的腳本中繼資料",
	"tool_script_symbols_desc": "列出解析得到的類別、方法、導出與列舉",
	"tool_script_exports_desc": "列出腳本宣告的導出成員",
	"tool_script_edit_gd_desc": "透過結構化輔助編輯 GDScript 檔案",

	# Editor tools
	"tool_editor_status_name": "狀態",
	"tool_editor_settings_name": "設定",
	"tool_editor_undo_redo_name": "復原重做",
	"tool_editor_notification_name": "通知",
	"tool_editor_inspector_name": "檢視器",
	"tool_editor_filesystem_name": "檔案系統",
	"tool_editor_plugin_name": "外掛",
	"tool_editor_status_desc": "取得編輯器狀態和場景資訊",
	"tool_editor_settings_desc": "讀取和修改編輯器設定",
	"tool_editor_undo_redo_desc": "管理復原與重做操作",
	"tool_editor_notification_desc": "顯示編輯器通知和對話框",
	"tool_editor_inspector_desc": "控制檢視器面板",
	"tool_editor_filesystem_desc": "與檔案系統面板互動",
	"tool_editor_plugin_desc": "查詢和管理編輯器外掛",

	# Debug tools
	"tool_debug_log_name": "日誌",
	"tool_debug_performance_name": "效能",
	"tool_debug_profiler_name": "分析器",
	"tool_debug_class_db_name": "類別資料庫",
	"tool_debug_log_desc": "列印除錯訊息和錯誤",
	"tool_debug_performance_desc": "監控效能指標",
	"tool_debug_profiler_desc": "分析程式碼執行",
	"tool_debug_class_db_desc": "查詢 Godot 類別資料庫",

	# Filesystem tools
	"tool_filesystem_directory_name": "目錄",
	"tool_filesystem_file_name": "檔案",
	"tool_filesystem_json_name": "JSON",
	"tool_filesystem_search_name": "搜尋",
	"tool_filesystem_directory_desc": "建立、刪除和列出目錄",
	"tool_filesystem_file_desc": "讀取、寫入和管理檔案",
	"tool_filesystem_json_desc": "讀寫 JSON 檔案",
	"tool_filesystem_search_desc": "按模式搜尋檔案",

	# Animation tools
	"tool_animation_player_name": "播放器",
	"tool_animation_animation_name": "動畫",
	"tool_animation_track_name": "軌道",
	"tool_animation_tween_name": "補間",
	"tool_animation_animation_tree_name": "動畫樹",
	"tool_animation_state_machine_name": "狀態機",
	"tool_animation_blend_space_name": "混合空間",
	"tool_animation_blend_tree_name": "混合樹",
	"tool_animation_player_desc": "控制 AnimationPlayer 節點",
	"tool_animation_animation_desc": "建立和修改動畫",
	"tool_animation_track_desc": "新增和編輯動畫軌道",
	"tool_animation_tween_desc": "建立和控制補間動畫",
	"tool_animation_animation_tree_desc": "設定和配置動畫樹",
	"tool_animation_state_machine_desc": "管理動畫狀態機",
	"tool_animation_blend_space_desc": "設定混合空間",
	"tool_animation_blend_tree_desc": "設定混合樹節點",

	# Material tools
	"tool_material_material_name": "材質",
	"tool_material_mesh_name": "網格",
	"tool_material_material_desc": "建立和修改材質",
	"tool_material_mesh_desc": "管理網格資源",

	# Shader tools
	"tool_shader_shader_name": "著色器",
	"tool_shader_shader_material_name": "著色器材質",
	"tool_shader_shader_desc": "建立和編輯著色器",
	"tool_shader_shader_material_desc": "將著色器套用到材質",

	# Lighting tools
	"tool_lighting_light_name": "燈光",
	"tool_lighting_environment_name": "環境",
	"tool_lighting_sky_name": "天空",
	"tool_lighting_light_desc": "建立和設定燈光",
	"tool_lighting_environment_desc": "設定世界環境",
	"tool_lighting_sky_desc": "配置天空和大氣",

	# Particle tools
	"tool_particle_particles_name": "粒子",
	"tool_particle_particle_material_name": "粒子材質",
	"tool_particle_particles_desc": "建立和設定粒子系統",
	"tool_particle_particle_material_desc": "設定粒子材質",

	# Tilemap tools
	"tool_tilemap_tileset_name": "圖塊集",
	"tool_tilemap_tilemap_name": "圖塊地圖",
	"tool_tilemap_tileset_desc": "建立和編輯圖塊集",
	"tool_tilemap_tilemap_desc": "編輯圖塊地圖圖層和單元格",

	# Geometry tools
	"tool_geometry_csg_name": "CSG",
	"tool_geometry_gridmap_name": "網格地圖",
	"tool_geometry_multimesh_name": "多網格",
	"tool_geometry_csg_desc": "建立 CSG 構造實體幾何",
	"tool_geometry_gridmap_desc": "編輯 3D 網格地圖",
	"tool_geometry_multimesh_desc": "設定多網格實例",

	# Physics tools
	"tool_physics_physics_body_name": "物理體",
	"tool_physics_collision_shape_name": "碰撞形狀",
	"tool_physics_physics_joint_name": "物理關節",
	"tool_physics_physics_query_name": "物理查詢",
	"tool_physics_physics_body_desc": "建立和設定物理體",
	"tool_physics_collision_shape_desc": "新增和修改碰撞形狀",
	"tool_physics_physics_joint_desc": "建立物理關節和約束",
	"tool_physics_physics_query_desc": "執行物理查詢和射線檢測",

	# Navigation tools
	"tool_navigation_navigation_name": "導航",
	"tool_navigation_navigation_desc": "設定導航網格和代理",

	# Audio tools
	"tool_audio_bus_name": "匯流排",
	"tool_audio_player_name": "播放器",
	"tool_audio_bus_desc": "管理音訊匯流排和效果",
	"tool_audio_player_desc": "控制音訊播放",

	# UI tools
	"tool_ui_theme_name": "主題",
	"tool_ui_control_name": "控制項",
	"tool_ui_theme_desc": "建立和修改 UI 主題",
	"tool_ui_control_desc": "設定控制項節點",

	# Signal tools
	"tool_signal_signal_name": "訊號",
	"tool_signal_signal_desc": "全域管理訊號連接",

	# Group tools
	"tool_group_group_name": "群組",
	"tool_group_group_desc": "全域查詢和管理節點群組",
}


static func get_translations() -> Dictionary:
	return TRANSLATIONS
