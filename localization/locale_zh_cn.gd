@tool
extends RefCounted

## 简体中文翻译

const TRANSLATIONS: Dictionary = {
	# Tab names
	"tab_server": "服务器",
	"tab_tools": "工具",
	"tab_config": "配置",

	# Header
	"title": "Godot MCP Server",
	"dialog_title": "Godot MCP",
	"status_running": "运行中",
	"status_stopped": "已停止",

	# Server tab
	"server_status": "服务器状态",
	"server_state_label": "状态：",
	"endpoint": "端点地址：",
	"connections": "连接数：",
	"active_connections": "活跃连接：",
	"total_requests": "总请求数：",
	"total_connections_short": "连接",
	"last_request": "最近请求：",
	"last_request_none": "暂无请求",
	"settings": "设置",
	"port": "端口：",
	"auto_start": "自动启动",
	"debug_log": "调试日志",
	"btn_start": "启动",
	"btn_restart": "重启",
	"btn_stop": "停止",
	"btn_reload_plugin": "完全重载插件",

	# About section
	"about": "关于",
	"author": "作者：",
	"wechat": "微信：",

	# Tools tab
	"tools_enabled": "工具：%d/%d 已启用",
	"tool_profile": "预设：",
	"tool_profile_slim": "精简",
	"tool_profile_default": "默认",
	"tool_profile_full": "完整",
	"tool_profile_slim_desc": "仅启用 Godot.NET 项目中最常用的基础检查、编辑与插件运行时工具。",
	"tool_profile_default_desc": "推荐日常使用，保留基础、插件、玩法、视觉/动画与界面相关工具。",
	"tool_profile_full_desc": "启用当前注册的全部工具分类。",
	"tool_profile_custom_desc": "自定义预设：%s",
	"tool_profile_modified_desc": "当前选择已修改，可点击“新增”保存为自定义预设。",
	"tool_profile_save_title": "保存自定义工具预设",
	"tool_profile_save_desc": "将当前工具选择保存为可复用的自定义预设文件。",
	"tool_profile_name_placeholder": "输入预设名称",
	"tool_profile_name_required": "预设名称不能为空",
	"tool_profile_saved": "预设已保存：%s",
	"tool_profile_save_failed": "保存预设失败",
	"btn_expand_all": "全部展开",
	"btn_collapse_all": "全部折叠",
	"btn_select_all": "全选",
	"btn_deselect_all": "全不选",
	"btn_add_profile": "新增",
	"btn_save_profile": "保存",
	"tools_server_unavailable": "服务不可用，请检查编辑器输出中的脚本加载错误。",
	"tools_load_errors": "有 %d 个工具分类因脚本加载失败被跳过，请查看编辑器输出。",

	# Tool categories - Core
	"cat_scene": "场景",
	"cat_node": "节点",
	"cat_script": "脚本",
	"cat_resource": "资源",
	"cat_filesystem": "文件系统",
	"cat_project": "项目",
	"cat_editor": "编辑器",
	"cat_plugin": "插件运行时",
	"cat_debug": "调试",
	"cat_animation": "动画",

	# Tool categories - Visual
	"cat_material": "材质",
	"cat_shader": "着色器",
	"cat_lighting": "灯光",
	"cat_particle": "粒子",

	# Tool categories - 2D
	"cat_tilemap": "瓦片地图",
	"cat_geometry": "几何体",

	# Tool categories - Gameplay
	"cat_physics": "物理",
	"cat_navigation": "导航",
	"cat_audio": "音频",

	# Tool categories - Utilities
	"cat_ui": "用户界面",
	"cat_signal": "信号",
	"cat_group": "分组",
	"domain_core": "核心",
	"domain_plugin": "插件",
	"domain_visual": "视觉",
	"domain_gameplay": "玩法",
	"domain_interface": "界面",
	"domain_other": "其他",

	# Config tab - IDE section
	"ide_config": "IDE 一键配置",
	"ide_config_desc": "点击后自动写入配置文件，重启客户端生效",
	"btn_one_click": "一键配置",
	"btn_copy": "复制",

	# Config tab - CLI section
	"cli_config": "CLI 命令行配置",
	"cli_config_desc": "复制命令并在终端中运行",
	"config_scope": "配置范围：",
	"scope_user": "用户级（全局）",
	"scope_project": "项目级（仅当前项目）",
	"btn_copy_cmd": "复制命令",

	# Messages
	"msg_config_success": "%s 配置成功！",
	"msg_config_failed": "配置失败",
	"msg_copied": "%s 已复制到剪贴板",
	"msg_parse_error": "配置解析失败",
	"msg_dir_error": "无法创建目录：",
	"msg_write_error": "无法写入配置文件",

	# Language
	"language": "语言：",

	# ==================== Tool Descriptions ====================
	# Scene tools
	"tool_scene_bindings_name": "绑定检查",
	"tool_scene_audit_name": "场景审计",
	"tool_scene_management_name": "管理",
	"tool_scene_hierarchy_name": "层级",
	"tool_scene_run_name": "运行",
	"tool_scene_management_desc": "打开、保存、创建和管理场景",
	"tool_scene_hierarchy_desc": "获取场景树结构和节点选择",
	"tool_scene_run_desc": "在编辑器中运行和测试场景",
	"tool_scene_bindings_desc": "检查场景中使用的导出脚本绑定",
	"tool_scene_audit_desc": "报告由导出绑定推导出的场景问题",

	# Node tools
	"tool_node_query_name": "查询",
	"tool_node_lifecycle_name": "生命周期",
	"tool_node_transform_name": "变换",
	"tool_node_property_name": "属性",
	"tool_node_hierarchy_name": "层级",
	"tool_node_signal_name": "信号",
	"tool_node_group_name": "分组",
	"tool_node_process_name": "处理",
	"tool_node_metadata_name": "元数据",
	"tool_node_call_name": "调用",
	"tool_node_visibility_name": "可见性",
	"tool_node_physics_name": "物理",
	"tool_node_query_desc": "按名称、类型或模式查找并检查节点",
	"tool_node_lifecycle_desc": "创建、删除、复制和实例化节点",
	"tool_node_transform_desc": "修改位置、旋转和缩放",
	"tool_node_property_desc": "获取和设置任意节点属性",
	"tool_node_hierarchy_desc": "管理父子关系和节点顺序",
	"tool_node_signal_desc": "连接、断开和发射信号",
	"tool_node_group_desc": "添加、移除和查询节点分组",
	"tool_node_process_desc": "控制节点处理模式",
	"tool_node_metadata_desc": "获取和设置节点元数据",
	"tool_node_call_desc": "动态调用节点方法",
	"tool_node_visibility_desc": "控制节点可见性和图层",
	"tool_node_physics_desc": "配置物理属性",

	# Resource tools
	"tool_resource_query_name": "查询",
	"tool_resource_manage_name": "管理",
	"tool_resource_texture_name": "纹理",
	"tool_resource_query_desc": "查找和检查资源",
	"tool_resource_manage_desc": "加载、保存和复制资源",
	"tool_resource_texture_desc": "管理纹理资源",

	# Project tools
	"tool_project_info_name": "信息",
	"tool_project_settings_name": "设置",
	"tool_project_input_name": "输入",
	"tool_project_autoload_name": "自动加载",
	"tool_project_info_desc": "获取项目信息和路径",
	"tool_project_settings_desc": "读取和修改项目设置",
	"tool_project_input_desc": "管理输入动作映射",
	"tool_project_autoload_desc": "管理自动加载单例",

	# Script tools
	"tool_script_read_name": "读取",
	"tool_script_open_name": "打开",
	"tool_script_inspect_name": "分析",
	"tool_script_symbols_name": "符号",
	"tool_script_exports_name": "导出",
	"tool_script_edit_gd_name": "编辑 GDScript",
	"tool_script_manage_desc": "创建、读取和修改脚本",
	"tool_script_attach_desc": "附加或分离节点脚本",
	"tool_script_edit_desc": "添加函数、变量和信号",
	"tool_script_open_desc": "在编辑器中打开脚本",
	"tool_script_read_desc": "以纯文本形式读取脚本文件",
	"tool_script_inspect_desc": "解析 GDScript 与 C# 的脚本元数据",
	"tool_script_symbols_desc": "列出解析得到的类、方法、导出与枚举",
	"tool_script_exports_desc": "列出脚本声明的导出成员",
	"tool_script_edit_gd_desc": "通过结构化辅助编辑 GDScript 文件",

	# Editor tools
	"tool_editor_status_name": "状态",
	"tool_editor_settings_name": "设置",
	"tool_editor_undo_redo_name": "撤销重做",
	"tool_editor_notification_name": "通知",
	"tool_editor_inspector_name": "检视器",
	"tool_editor_filesystem_name": "文件系统",
	"tool_editor_plugin_name": "插件",
	"tool_editor_status_desc": "获取编辑器状态和场景信息",
	"tool_editor_settings_desc": "读取和修改编辑器设置",
	"tool_editor_undo_redo_desc": "管理撤销和重做操作",
	"tool_editor_notification_desc": "显示编辑器通知和对话框",
	"tool_editor_inspector_desc": "控制检视器面板",
	"tool_editor_filesystem_desc": "与文件系统面板交互",
	"tool_editor_plugin_desc": "查询和管理编辑器插件",
	"tool_plugin_runtime_name": "运行时",
	"tool_plugin_runtime_desc": "查看加载器状态、重载工具域并读取运行时摘要",

	# Debug tools
	"tool_debug_log_name": "日志",
	"tool_debug_performance_name": "性能",
	"tool_debug_profiler_name": "分析器",
	"tool_debug_class_db_name": "类数据库",
	"tool_debug_log_desc": "打印调试消息和错误",
	"tool_debug_performance_desc": "监控性能指标",
	"tool_debug_profiler_desc": "分析代码执行",
	"tool_debug_class_db_desc": "查询 Godot 类数据库",

	# Filesystem tools
	"tool_filesystem_directory_name": "目录",
	"tool_filesystem_file_name": "文件",
	"tool_filesystem_json_name": "JSON",
	"tool_filesystem_search_name": "搜索",
	"tool_filesystem_directory_desc": "创建、删除和列出目录",
	"tool_filesystem_file_desc": "读取、写入和管理文件",
	"tool_filesystem_json_desc": "读写 JSON 文件",
	"tool_filesystem_search_desc": "按模式搜索文件",

	# Animation tools
	"tool_animation_player_name": "播放器",
	"tool_animation_animation_name": "动画",
	"tool_animation_track_name": "轨道",
	"tool_animation_tween_name": "补间",
	"tool_animation_animation_tree_name": "动画树",
	"tool_animation_state_machine_name": "状态机",
	"tool_animation_blend_space_name": "混合空间",
	"tool_animation_blend_tree_name": "混合树",
	"tool_animation_player_desc": "控制 AnimationPlayer 节点",
	"tool_animation_animation_desc": "创建和修改动画",
	"tool_animation_track_desc": "添加和编辑动画轨道",
	"tool_animation_tween_desc": "创建和控制补间动画",
	"tool_animation_animation_tree_desc": "设置和配置动画树",
	"tool_animation_state_machine_desc": "管理动画状态机",
	"tool_animation_blend_space_desc": "配置混合空间",
	"tool_animation_blend_tree_desc": "设置混合树节点",

	# Material tools
	"tool_material_material_name": "材质",
	"tool_material_mesh_name": "网格",
	"tool_material_material_desc": "创建和修改材质",
	"tool_material_mesh_desc": "管理网格资源",

	# Shader tools
	"tool_shader_shader_name": "着色器",
	"tool_shader_shader_material_name": "着色器材质",
	"tool_shader_shader_desc": "创建和编辑着色器",
	"tool_shader_shader_material_desc": "将着色器应用到材质",

	# Lighting tools
	"tool_lighting_light_name": "灯光",
	"tool_lighting_environment_name": "环境",
	"tool_lighting_sky_name": "天空",
	"tool_lighting_light_desc": "创建和配置灯光",
	"tool_lighting_environment_desc": "设置世界环境",
	"tool_lighting_sky_desc": "配置天空和大气",

	# Particle tools
	"tool_particle_particles_name": "粒子",
	"tool_particle_particle_material_name": "粒子材质",
	"tool_particle_particles_desc": "创建和配置粒子系统",
	"tool_particle_particle_material_desc": "设置粒子材质",

	# Tilemap tools
	"tool_tilemap_tileset_name": "瓦片集",
	"tool_tilemap_tilemap_name": "瓦片地图",
	"tool_tilemap_tileset_desc": "创建和编辑瓦片集",
	"tool_tilemap_tilemap_desc": "编辑瓦片地图图层和单元格",

	# Geometry tools
	"tool_geometry_csg_name": "CSG",
	"tool_geometry_gridmap_name": "网格地图",
	"tool_geometry_multimesh_name": "多网格",
	"tool_geometry_csg_desc": "创建 CSG 构造实体几何",
	"tool_geometry_gridmap_desc": "编辑 3D 网格地图",
	"tool_geometry_multimesh_desc": "设置多网格实例",

	# Physics tools
	"tool_physics_physics_body_name": "物理体",
	"tool_physics_collision_shape_name": "碰撞形状",
	"tool_physics_physics_joint_name": "物理关节",
	"tool_physics_physics_query_name": "物理查询",
	"tool_physics_physics_body_desc": "创建和配置物理体",
	"tool_physics_collision_shape_desc": "添加和修改碰撞形状",
	"tool_physics_physics_joint_desc": "创建物理关节和约束",
	"tool_physics_physics_query_desc": "执行物理查询和射线检测",

	# Navigation tools
	"tool_navigation_navigation_name": "导航",
	"tool_navigation_navigation_desc": "设置导航网格和代理",

	# Audio tools
	"tool_audio_bus_name": "总线",
	"tool_audio_player_name": "播放器",
	"tool_audio_bus_desc": "管理音频总线和效果",
	"tool_audio_player_desc": "控制音频播放",

	# UI tools
	"tool_ui_theme_name": "主题",
	"tool_ui_control_name": "控件",
	"tool_ui_theme_desc": "创建和修改 UI 主题",
	"tool_ui_control_desc": "配置控件节点",

	# Signal tools
	"tool_signal_signal_name": "信号",
	"tool_signal_signal_desc": "全局管理信号连接",

	# Group tools
	"tool_group_group_name": "分组",
	"tool_group_group_desc": "全局查询和管理节点分组",
}


static func get_translations() -> Dictionary:
	return TRANSLATIONS
