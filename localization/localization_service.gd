@tool
extends RefCounted
class_name LocalizationService

static var _instance: LocalizationService = null

var _current_language := "en"
var _translations: Dictionary = {}

const AVAILABLE_LANGUAGES: Dictionary = {
	"en": "English",
	"zh_CN": "Simplified Chinese",
	"zh_TW": "Traditional Chinese",
	"ja": "Japanese",
	"ru": "Russian",
	"fr": "French",
	"pt": "Portuguese",
	"es": "Spanish",
	"de": "German"
}

const LANGUAGE_NATIVE_NAMES: Dictionary = {
	"en": "English",
	"zh_CN": "简体中文",
	"zh_TW": "繁體中文",
	"ja": "日本語",
	"ru": "Русский",
	"fr": "Français",
	"pt": "Português",
	"es": "Español",
	"de": "Deutsch"
}

const LANGUAGE_FILES: Dictionary = {
	"en": "res://addons/godot_dotnet_mcp/localization/locale_en.gd",
	"zh_CN": "res://addons/godot_dotnet_mcp/localization/locale_zh_cn.gd",
	"zh_TW": "res://addons/godot_dotnet_mcp/localization/locale_zh_tw.gd",
	"ja": "res://addons/godot_dotnet_mcp/localization/locale_ja.gd",
	"ru": "res://addons/godot_dotnet_mcp/localization/locale_ru.gd",
	"fr": "res://addons/godot_dotnet_mcp/localization/locale_fr.gd",
	"pt": "res://addons/godot_dotnet_mcp/localization/locale_pt.gd",
	"es": "res://addons/godot_dotnet_mcp/localization/locale_es.gd",
	"de": "res://addons/godot_dotnet_mcp/localization/locale_de.gd"
}

const SUPPLEMENTAL_TRANSLATIONS: Dictionary = {
	"en": {
		"dialog_title": "Godot MCP",
		"server_state_label": "State:",
		"active_connections": "Active Connections:",
		"total_requests": "Total Requests:",
		"total_connections_short": "connections",
		"last_request": "Last Request:",
		"last_request_none": "No requests yet",
		"btn_restart": "Restart",
		"btn_reload_plugin": "Reload Plugin",
		"tool_profile": "Profile:",
		"tool_profile_slim": "Slim",
		"tool_profile_default": "Default",
		"tool_profile_full": "Full",
		"tool_profile_slim_desc": "Enable the core inspection and editing tools used most often in Godot.NET projects.",
		"tool_profile_default_desc": "Recommended everyday preset. Keeps core, gameplay, animation and UI tools available.",
		"tool_profile_full_desc": "Expose every registered tool category.",
		"tool_profile_custom_desc": "Custom preset: %s",
		"tool_profile_modified_desc": "Current selection has been modified. Use Add to save it as a custom preset.",
		"tool_profile_save_title": "Save Custom Tool Preset",
		"tool_profile_save_desc": "Save the current tool selection as a reusable custom preset file.",
		"tool_profile_name_placeholder": "Preset name",
		"tool_profile_name_required": "Preset name is required",
		"tool_profile_saved": "Preset saved: %s",
		"tool_profile_save_failed": "Failed to save preset",
		"btn_add_profile": "Add",
		"btn_save_profile": "Save",
		"tools_load_errors": "Skipped %d tool categories due to script load errors. See editor output for details.",
		"domain_core": "Core",
		"domain_visual": "Visual",
		"domain_gameplay": "Gameplay",
		"domain_interface": "Interface",
		"domain_other": "Other",
		"tab_tools": "Tools",
		"tab_config": "Config",
		"settings": "Settings",
		"btn_stop": "Stop",
		"btn_expand_all": "Expand All",
		"btn_collapse_all": "Collapse All",
		"config_client_claude_desktop": "Claude Desktop",
		"config_client_cursor": "Cursor",
		"config_client_claude_code": "Claude Code",
		"config_client_codex": "Codex",
		"config_client_gemini": "Gemini",
		"config_header": "Connect Clients",
		"config_header_desc": "Use one-click file setup for desktop clients, or copy the verified command for CLI-based agents.",
		"config_platform": "Agent platform:",
		"config_section_desktop": "Config Files",
		"config_section_desktop_desc": "These clients read JSON config files. The generated snippet only updates the `godot-mcp` server entry.",
		"config_scope_claude": "Claude Code scope:",
		"config_file_path": "Config file path:",
		"config_client_claude_desktop_desc": "Writes the standard desktop config JSON using the MCP `url` field.",
		"config_client_cursor_desc": "Writes `~/.cursor/mcp.json` using the MCP `url` field.",
		"config_client_claude_code_desc": "Verified command based on Claude Code HTTP transport syntax and the selected scope.",
		"config_client_codex_desc": "Verified Codex CLI command using the official `codex mcp add <name> --url <url>` syntax.",
		"config_client_gemini_desc": "Writes `~/.gemini/settings.json` using `httpUrl`, which Gemini CLI currently expects for HTTP MCP servers.",
		"config_section_tools": "Tool Categories",
		"tools_toggle_column": "On",
		"tools_enabled_count": "Enabled",
		"btn_write_config": "Write Config",
		"tool_scene_run_name": "Run",
		"tool_node_transform_name": "Transform",
		"tool_node_property_name": "Property",
		"tool_node_process_name": "Process",
		"tool_node_metadata_name": "Metadata",
		"tool_resource_texture_name": "Texture",
		"tool_project_settings_name": "Settings",
		"tool_script_open_name": "Open",
		"tool_script_inspect_name": "Inspect",
		"tool_editor_settings_name": "Settings",
		"language_name_en": "English",
		"language_name_zh_CN": "Simplified Chinese",
		"language_name_zh_TW": "Traditional Chinese",
		"language_name_ja": "Japanese",
		"language_name_ru": "Russian",
		"language_name_fr": "French",
		"language_name_pt": "Portuguese",
		"language_name_es": "Spanish",
		"language_name_de": "German"
	},
	"zh_CN": {
		"dialog_title": "Godot MCP",
		"server_state_label": "状态：",
		"active_connections": "活跃连接：",
		"total_requests": "总请求数：",
		"total_connections_short": "连接",
		"last_request": "最近请求：",
		"last_request_none": "暂无请求",
		"btn_restart": "重启",
		"btn_reload_plugin": "完全重载插件",
		"tool_profile": "预设：",
		"tool_profile_slim": "精简",
		"tool_profile_default": "默认",
		"tool_profile_full": "完整",
		"tool_profile_slim_desc": "仅启用 Godot.NET 项目中最常用的核心检查与编辑工具。",
		"tool_profile_default_desc": "推荐日常使用，保留核心、玩法、动画与界面相关工具。",
		"tool_profile_full_desc": "启用当前注册的全部工具分类。",
		"tool_profile_custom_desc": "自定义预设：%s",
		"tool_profile_modified_desc": "当前选择已修改，可点击“新增”保存为自定义预设。",
		"tool_profile_save_title": "保存自定义工具预设",
		"tool_profile_save_desc": "将当前工具选择保存为可复用的自定义预设文件。",
		"tool_profile_name_placeholder": "输入预设名称",
		"tool_profile_name_required": "预设名称不能为空",
		"tool_profile_saved": "预设已保存：%s",
		"tool_profile_save_failed": "保存预设失败",
		"btn_add_profile": "新增",
		"btn_save_profile": "保存",
		"tools_load_errors": "有 %d 个工具分类因脚本加载失败被跳过，请查看编辑器输出。",
		"domain_core": "核心",
		"domain_visual": "视觉",
		"domain_gameplay": "玩法",
		"domain_interface": "界面",
		"domain_other": "其他",
		"tab_tools": "工具",
		"tab_config": "配置",
		"settings": "设置",
		"btn_stop": "停止",
		"btn_expand_all": "全部展开",
		"btn_collapse_all": "全部折叠",
		"config_client_claude_desktop": "Claude Desktop",
		"config_client_cursor": "Cursor",
		"config_client_claude_code": "Claude Code",
		"config_client_codex": "Codex",
		"config_client_gemini": "Gemini",
		"config_header": "连接客户端",
		"config_header_desc": "桌面客户端可直接一键写入配置，CLI 客户端则提供已核对的接入命令。",
		"config_platform": "Agent 平台：",
		"config_section_desktop": "配置文件",
		"config_section_desktop_desc": "这些客户端读取 JSON 配置文件。生成内容只会更新 `godot-mcp` 这一项，不覆盖其它服务器。",
		"config_scope_claude": "Claude Code 作用域：",
		"config_file_path": "配置文件路径：",
		"config_client_claude_desktop_desc": "写入标准桌面端配置，使用 MCP 的 `url` 字段。",
		"config_client_cursor_desc": "写入 `~/.cursor/mcp.json`，使用 MCP 的 `url` 字段。",
		"config_client_claude_code_desc": "按 Claude Code 官方 HTTP 传输命令格式生成，并带上当前作用域。",
		"config_client_codex_desc": "按官方 `codex mcp add <name> --url <url>` 语法生成。",
		"config_client_gemini_desc": "写入 `~/.gemini/settings.json`，对 HTTP MCP 服务使用 Gemini CLI 当前采用的 `httpUrl` 字段。",
		"config_section_tools": "工具分类",
		"tools_toggle_column": "开关",
		"tools_enabled_count": "启用情况",
		"btn_write_config": "写入配置",
		"tool_scene_run_name": "运行",
		"tool_node_transform_name": "变换",
		"tool_node_property_name": "属性",
		"tool_node_process_name": "处理",
		"tool_node_metadata_name": "元数据",
		"tool_resource_texture_name": "纹理",
		"tool_project_settings_name": "设置",
		"tool_script_open_name": "打开",
		"tool_script_inspect_name": "分析",
		"tool_editor_settings_name": "设置",
		"language_name_en": "英文",
		"language_name_zh_CN": "简体中文",
		"language_name_zh_TW": "繁体中文",
		"language_name_ja": "日语",
		"language_name_ru": "俄语",
		"language_name_fr": "法语",
		"language_name_pt": "葡萄牙语",
		"language_name_es": "西班牙语",
		"language_name_de": "德语"
	},
	"zh_TW": {
		"dialog_title": "Godot MCP",
		"server_state_label": "狀態：",
		"active_connections": "活躍連線：",
		"total_requests": "總請求數：",
		"total_connections_short": "連線",
		"last_request": "最近請求：",
		"last_request_none": "暫無請求",
		"btn_restart": "重新啟動",
		"btn_reload_plugin": "完整重載外掛",
		"tool_profile": "預設：",
		"tool_profile_slim": "精簡",
		"tool_profile_default": "預設",
		"tool_profile_full": "完整",
		"tool_profile_slim_desc": "僅啟用 Godot.NET 專案中最常用的核心檢查與編輯工具。",
		"tool_profile_default_desc": "建議日常使用，保留核心、玩法、動畫與介面工具。",
		"tool_profile_full_desc": "啟用目前註冊的全部工具分類。",
		"tool_profile_custom_desc": "自訂預設：%s",
		"tool_profile_modified_desc": "目前選擇已修改，可點擊「新增」另存為自訂預設。",
		"tool_profile_save_title": "儲存自訂工具預設",
		"tool_profile_save_desc": "將目前工具選擇儲存為可重用的自訂預設檔案。",
		"tool_profile_name_placeholder": "輸入預設名稱",
		"tool_profile_name_required": "預設名稱不能為空",
		"tool_profile_saved": "預設已儲存：%s",
		"tool_profile_save_failed": "儲存預設失敗",
		"btn_add_profile": "新增",
		"btn_save_profile": "儲存",
		"tools_load_errors": "有 %d 個工具分類因腳本載入失敗被跳過，請查看編輯器輸出。",
		"domain_core": "核心",
		"domain_visual": "視覺",
		"domain_gameplay": "玩法",
		"domain_interface": "介面",
		"domain_other": "其他",
		"config_client_claude_desktop": "Claude Desktop",
		"config_client_cursor": "Cursor",
		"config_client_claude_code": "Claude Code",
		"config_client_codex": "Codex",
		"config_client_gemini": "Gemini",
		"language_name_en": "英文",
		"language_name_zh_CN": "簡體中文",
		"language_name_zh_TW": "繁體中文",
		"language_name_ja": "日文",
		"language_name_ru": "俄文",
		"language_name_fr": "法文",
		"language_name_pt": "葡萄牙文",
		"language_name_es": "西班牙文",
		"language_name_de": "德文"
	},
	"ja": {
		"dialog_title": "Godot MCP",
		"server_state_label": "状態:",
		"active_connections": "アクティブ接続:",
		"total_requests": "総リクエスト数:",
		"total_connections_short": "接続",
		"last_request": "最新リクエスト:",
		"last_request_none": "まだリクエストはありません",
		"btn_restart": "再起動",
		"btn_reload_plugin": "プラグインを完全再読み込み",
		"tool_profile": "プリセット:",
		"tool_profile_slim": "簡易",
		"tool_profile_default": "標準",
		"tool_profile_full": "完全",
		"tool_profile_slim_desc": "Godot.NET プロジェクトで最もよく使う中核の検査・編集ツールのみを有効化します。",
		"tool_profile_default_desc": "日常利用向けの推奨プリセットです。中核、ゲームプレイ、アニメーション、UI ツールを残します。",
		"tool_profile_full_desc": "登録済みの全ツールカテゴリを公開します。",
		"tool_profile_custom_desc": "カスタムプリセット: %s",
		"tool_profile_modified_desc": "現在の選択は変更されています。追加からカスタムプリセットとして保存できます。",
		"tool_profile_save_title": "カスタムツールプリセットを保存",
		"tool_profile_save_desc": "現在のツール選択を再利用可能なカスタムプリセットとして保存します。",
		"tool_profile_name_placeholder": "プリセット名",
		"tool_profile_name_required": "プリセット名は必須です",
		"tool_profile_saved": "プリセットを保存しました: %s",
		"tool_profile_save_failed": "プリセットの保存に失敗しました",
		"btn_add_profile": "追加",
		"btn_save_profile": "保存",
		"tools_load_errors": "スクリプト読み込みエラーのため %d 個のツールカテゴリをスキップしました。詳細はエディター出力を確認してください。",
		"domain_core": "コア",
		"domain_visual": "ビジュアル",
		"domain_gameplay": "ゲームプレイ",
		"domain_interface": "インターフェース",
		"domain_other": "その他",
		"config_client_claude_desktop": "Claude Desktop",
		"config_client_cursor": "Cursor",
		"config_client_claude_code": "Claude Code",
		"config_client_codex": "Codex",
		"config_client_gemini": "Gemini",
		"language_name_en": "英語",
		"language_name_zh_CN": "簡体字中国語",
		"language_name_zh_TW": "繁体字中国語",
		"language_name_ja": "日本語",
		"language_name_ru": "ロシア語",
		"language_name_fr": "フランス語",
		"language_name_pt": "ポルトガル語",
		"language_name_es": "スペイン語",
		"language_name_de": "ドイツ語"
	},
	"ru": {
		"dialog_title": "Godot MCP",
		"server_state_label": "Состояние:",
		"active_connections": "Активные подключения:",
		"total_requests": "Всего запросов:",
		"total_connections_short": "подключения",
		"last_request": "Последний запрос:",
		"last_request_none": "Запросов пока нет",
		"btn_restart": "Перезапустить",
		"btn_reload_plugin": "Полностью перезагрузить плагин",
		"tool_profile": "Профиль:",
		"tool_profile_slim": "Минимальный",
		"tool_profile_default": "Стандартный",
		"tool_profile_full": "Полный",
		"tool_profile_slim_desc": "Включает только основные инструменты проверки и редактирования, которые чаще всего используются в проектах Godot.NET.",
		"tool_profile_default_desc": "Рекомендуемый ежедневный набор. Оставляет основные, игровые, анимационные и UI-инструменты.",
		"tool_profile_full_desc": "Открывает все зарегистрированные категории инструментов.",
		"tool_profile_custom_desc": "Пользовательский профиль: %s",
		"tool_profile_modified_desc": "Текущий выбор изменён. Используйте Добавить, чтобы сохранить его как пользовательский профиль.",
		"tool_profile_save_title": "Сохранить пользовательский профиль инструментов",
		"tool_profile_save_desc": "Сохранить текущий выбор инструментов как повторно используемый пользовательский профиль.",
		"tool_profile_name_placeholder": "Имя профиля",
		"tool_profile_name_required": "Имя профиля обязательно",
		"tool_profile_saved": "Профиль сохранён: %s",
		"tool_profile_save_failed": "Не удалось сохранить профиль",
		"btn_add_profile": "Добавить",
		"btn_save_profile": "Сохранить",
		"tools_load_errors": "Пропущено %d категорий инструментов из-за ошибок загрузки скриптов. Подробности в выводе редактора.",
		"domain_core": "Основа",
		"domain_visual": "Визуал",
		"domain_gameplay": "Геймплей",
		"domain_interface": "Интерфейс",
		"domain_other": "Другое",
		"config_client_claude_desktop": "Claude Desktop",
		"config_client_cursor": "Cursor",
		"config_client_claude_code": "Claude Code",
		"config_client_codex": "Codex",
		"config_client_gemini": "Gemini",
		"language_name_en": "английский",
		"language_name_zh_CN": "упрощённый китайский",
		"language_name_zh_TW": "традиционный китайский",
		"language_name_ja": "японский",
		"language_name_ru": "русский",
		"language_name_fr": "французский",
		"language_name_pt": "португальский",
		"language_name_es": "испанский",
		"language_name_de": "немецкий"
	},
	"fr": {
		"dialog_title": "Godot MCP",
		"server_state_label": "État :",
		"active_connections": "Connexions actives :",
		"total_requests": "Nombre total de requêtes :",
		"total_connections_short": "connexions",
		"last_request": "Dernière requête :",
		"last_request_none": "Aucune requête pour le moment",
		"btn_restart": "Redémarrer",
		"btn_reload_plugin": "Recharger complètement le plugin",
		"tool_profile": "Profil :",
		"tool_profile_slim": "Allégé",
		"tool_profile_default": "Par défaut",
		"tool_profile_full": "Complet",
		"tool_profile_slim_desc": "Active uniquement les outils d'inspection et d'édition essentiels les plus utilisés dans les projets Godot.NET.",
		"tool_profile_default_desc": "Préréglage recommandé au quotidien. Conserve les outils principaux, gameplay, animation et UI.",
		"tool_profile_full_desc": "Expose toutes les catégories d'outils enregistrées.",
		"tool_profile_custom_desc": "Profil personnalisé : %s",
		"tool_profile_modified_desc": "La sélection actuelle a été modifiée. Utilisez Ajouter pour l'enregistrer comme profil personnalisé.",
		"tool_profile_save_title": "Enregistrer un profil d'outils personnalisé",
		"tool_profile_save_desc": "Enregistrer la sélection actuelle d'outils comme profil personnalisé réutilisable.",
		"tool_profile_name_placeholder": "Nom du profil",
		"tool_profile_name_required": "Le nom du profil est obligatoire",
		"tool_profile_saved": "Profil enregistré : %s",
		"tool_profile_save_failed": "Échec de l'enregistrement du profil",
		"btn_add_profile": "Ajouter",
		"btn_save_profile": "Enregistrer",
		"tools_load_errors": "%d catégories d'outils ont été ignorées à cause d'erreurs de chargement de script. Voir la sortie de l'éditeur.",
		"domain_core": "Noyau",
		"domain_visual": "Visuel",
		"domain_gameplay": "Gameplay",
		"domain_interface": "Interface",
		"domain_other": "Autre",
		"config_client_claude_desktop": "Claude Desktop",
		"config_client_cursor": "Cursor",
		"config_client_claude_code": "Claude Code",
		"config_client_codex": "Codex",
		"config_client_gemini": "Gemini",
		"language_name_en": "anglais",
		"language_name_zh_CN": "chinois simplifié",
		"language_name_zh_TW": "chinois traditionnel",
		"language_name_ja": "japonais",
		"language_name_ru": "russe",
		"language_name_fr": "français",
		"language_name_pt": "portugais",
		"language_name_es": "espagnol",
		"language_name_de": "allemand"
	},
	"pt": {
		"dialog_title": "Godot MCP",
		"server_state_label": "Estado:",
		"active_connections": "Conexões ativas:",
		"total_requests": "Total de solicitações:",
		"total_connections_short": "conexões",
		"last_request": "Última solicitação:",
		"last_request_none": "Nenhuma solicitação ainda",
		"btn_restart": "Reiniciar",
		"btn_reload_plugin": "Recarregar plugin por completo",
		"tool_profile": "Perfil:",
		"tool_profile_slim": "Enxuto",
		"tool_profile_default": "Padrão",
		"tool_profile_full": "Completo",
		"tool_profile_slim_desc": "Ativa apenas as ferramentas centrais de inspeção e edição mais usadas em projetos Godot.NET.",
		"tool_profile_default_desc": "Predefinição recomendada para o dia a dia. Mantém ferramentas centrais, de gameplay, animação e UI.",
		"tool_profile_full_desc": "Expõe todas as categorias de ferramentas registradas.",
		"tool_profile_custom_desc": "Perfil personalizado: %s",
		"tool_profile_modified_desc": "A seleção atual foi modificada. Use Adicionar para salvá-la como perfil personalizado.",
		"tool_profile_save_title": "Salvar perfil de ferramentas personalizado",
		"tool_profile_save_desc": "Salve a seleção atual de ferramentas como um perfil personalizado reutilizável.",
		"tool_profile_name_placeholder": "Nome do perfil",
		"tool_profile_name_required": "O nome do perfil é obrigatório",
		"tool_profile_saved": "Perfil salvo: %s",
		"tool_profile_save_failed": "Falha ao salvar o perfil",
		"btn_add_profile": "Adicionar",
		"btn_save_profile": "Salvar",
		"tools_load_errors": "%d categorias de ferramentas foram ignoradas devido a erros ao carregar scripts. Veja a saída do editor.",
		"domain_core": "Núcleo",
		"domain_visual": "Visual",
		"domain_gameplay": "Jogabilidade",
		"domain_interface": "Interface",
		"domain_other": "Outros",
		"config_client_claude_desktop": "Claude Desktop",
		"config_client_cursor": "Cursor",
		"config_client_claude_code": "Claude Code",
		"config_client_codex": "Codex",
		"config_client_gemini": "Gemini",
		"language_name_en": "inglês",
		"language_name_zh_CN": "chinês simplificado",
		"language_name_zh_TW": "chinês tradicional",
		"language_name_ja": "japonês",
		"language_name_ru": "russo",
		"language_name_fr": "francês",
		"language_name_pt": "português",
		"language_name_es": "espanhol",
		"language_name_de": "alemão"
	},
	"es": {
		"dialog_title": "Godot MCP",
		"server_state_label": "Estado:",
		"active_connections": "Conexiones activas:",
		"total_requests": "Solicitudes totales:",
		"total_connections_short": "conexiones",
		"last_request": "Última solicitud:",
		"last_request_none": "Aún no hay solicitudes",
		"btn_restart": "Reiniciar",
		"btn_reload_plugin": "Recargar complemento por completo",
		"tool_profile": "Perfil:",
		"tool_profile_slim": "Ligero",
		"tool_profile_default": "Predeterminado",
		"tool_profile_full": "Completo",
		"tool_profile_slim_desc": "Activa solo las herramientas principales de inspección y edición más usadas en proyectos Godot.NET.",
		"tool_profile_default_desc": "Preajuste recomendado para el uso diario. Mantiene herramientas centrales, de gameplay, animación y UI.",
		"tool_profile_full_desc": "Expone todas las categorías de herramientas registradas.",
		"tool_profile_custom_desc": "Perfil personalizado: %s",
		"tool_profile_modified_desc": "La selección actual ha sido modificada. Usa Agregar para guardarla como perfil personalizado.",
		"tool_profile_save_title": "Guardar perfil de herramientas personalizado",
		"tool_profile_save_desc": "Guarda la selección actual de herramientas como un perfil personalizado reutilizable.",
		"tool_profile_name_placeholder": "Nombre del perfil",
		"tool_profile_name_required": "El nombre del perfil es obligatorio",
		"tool_profile_saved": "Perfil guardado: %s",
		"tool_profile_save_failed": "No se pudo guardar el perfil",
		"btn_add_profile": "Agregar",
		"btn_save_profile": "Guardar",
		"tools_load_errors": "Se omitieron %d categorías de herramientas por errores al cargar scripts. Revisa la salida del editor.",
		"domain_core": "Núcleo",
		"domain_visual": "Visual",
		"domain_gameplay": "Jugabilidad",
		"domain_interface": "Interfaz",
		"domain_other": "Otros",
		"config_client_claude_desktop": "Claude Desktop",
		"config_client_cursor": "Cursor",
		"config_client_claude_code": "Claude Code",
		"config_client_codex": "Codex",
		"config_client_gemini": "Gemini",
		"language_name_en": "inglés",
		"language_name_zh_CN": "chino simplificado",
		"language_name_zh_TW": "chino tradicional",
		"language_name_ja": "japonés",
		"language_name_ru": "ruso",
		"language_name_fr": "francés",
		"language_name_pt": "portugués",
		"language_name_es": "español",
		"language_name_de": "alemán"
	},
	"de": {
		"dialog_title": "Godot MCP",
		"server_state_label": "Status:",
		"active_connections": "Aktive Verbindungen:",
		"total_requests": "Gesamtanfragen:",
		"total_connections_short": "Verbindungen",
		"last_request": "Letzte Anfrage:",
		"last_request_none": "Noch keine Anfragen",
		"btn_restart": "Neu starten",
		"btn_reload_plugin": "Plugin vollständig neu laden",
		"tool_profile": "Profil:",
		"tool_profile_slim": "Schlank",
		"tool_profile_default": "Standard",
		"tool_profile_full": "Voll",
		"tool_profile_slim_desc": "Aktiviert nur die wichtigsten Prüf- und Bearbeitungswerkzeuge, die in Godot.NET-Projekten am häufigsten verwendet werden.",
		"tool_profile_default_desc": "Empfohlenes Alltagsprofil. Behält Kern-, Gameplay-, Animations- und UI-Werkzeuge bei.",
		"tool_profile_full_desc": "Stellt alle registrierten Werkzeugkategorien bereit.",
		"tool_profile_custom_desc": "Benutzerdefiniertes Profil: %s",
		"tool_profile_modified_desc": "Die aktuelle Auswahl wurde geändert. Mit Hinzufügen kannst du sie als benutzerdefiniertes Profil speichern.",
		"tool_profile_save_title": "Benutzerdefiniertes Werkzeugprofil speichern",
		"tool_profile_save_desc": "Speichert die aktuelle Werkzeugauswahl als wiederverwendbares benutzerdefiniertes Profil.",
		"tool_profile_name_placeholder": "Profilname",
		"tool_profile_name_required": "Profilname ist erforderlich",
		"tool_profile_saved": "Profil gespeichert: %s",
		"tool_profile_save_failed": "Profil konnte nicht gespeichert werden",
		"btn_add_profile": "Hinzufügen",
		"btn_save_profile": "Speichern",
		"tools_load_errors": "%d Werkzeugkategorien wurden wegen Skriptladefehlern übersprungen. Details siehe Editor-Ausgabe.",
		"domain_core": "Kern",
		"domain_visual": "Visuell",
		"domain_gameplay": "Gameplay",
		"domain_interface": "Oberfläche",
		"domain_other": "Andere",
		"config_client_claude_desktop": "Claude Desktop",
		"config_client_cursor": "Cursor",
		"config_client_claude_code": "Claude Code",
		"config_client_codex": "Codex",
		"config_client_gemini": "Gemini",
		"language_name_en": "Englisch",
		"language_name_zh_CN": "Vereinfachtes Chinesisch",
		"language_name_zh_TW": "Traditionelles Chinesisch",
		"language_name_ja": "Japanisch",
		"language_name_ru": "Russisch",
		"language_name_fr": "Französisch",
		"language_name_pt": "Portugiesisch",
		"language_name_es": "Spanisch",
		"language_name_de": "Deutsch"
	}
}

static func get_instance() -> LocalizationService:
	if _instance == null:
		_instance = LocalizationService.new()
		_instance._init_translations()
	return _instance


static func reset_instance() -> void:
	_instance = null


func _init_translations() -> void:
	_translations.clear()
	for lang_code in LANGUAGE_FILES:
		var file_path := str(LANGUAGE_FILES[lang_code])
		if not ResourceLoader.exists(file_path):
			continue
		var translations_value = _load_language_translations(file_path)
		if not (translations_value is Dictionary):
			continue
		_translations[lang_code] = _build_language_map(translations_value, SUPPLEMENTAL_TRANSLATIONS.get(lang_code, {}))

	_current_language = _detect_system_language()


func _load_language_translations(file_path: String):
	var lang_script = ResourceLoader.load(file_path, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	if lang_script == null:
		return {}

	if lang_script is Script:
		(lang_script as Script).reload()

	if lang_script.has_method("get_translations"):
		return lang_script.call("get_translations")

	return lang_script.get("TRANSLATIONS")


func _build_language_map(base_translations, supplemental_translations) -> Dictionary:
	var merged := {}

	if base_translations is Dictionary:
		merged = (base_translations as Dictionary).duplicate(true)

	if supplemental_translations is Dictionary:
		var supplemental_copy := (supplemental_translations as Dictionary).duplicate(true)
		for key in supplemental_copy.keys():
			merged[key] = supplemental_copy[key]

	return merged


func _detect_system_language() -> String:
	var locale := OS.get_locale()
	if AVAILABLE_LANGUAGES.has(locale):
		return locale

	var lang_code := locale.split("_")[0]
	match lang_code:
		"zh":
			var lower_locale := locale.to_lower()
			if lower_locale.contains("tw") or lower_locale.contains("hk") or lower_locale.contains("hant"):
				return "zh_TW"
			return "zh_CN"
		"ja":
			return "ja"
		"ru":
			return "ru"
		"fr":
			return "fr"
		"pt":
			return "pt"
		"es":
			return "es"
		"de":
			return "de"
		_:
			return "en"


func set_language(lang_code: String) -> void:
	if lang_code.is_empty():
		_current_language = _detect_system_language()
		return
	if AVAILABLE_LANGUAGES.has(lang_code):
		_current_language = lang_code


func get_language() -> String:
	return _current_language


func get_available_languages() -> Dictionary:
	return AVAILABLE_LANGUAGES


func get_language_display_name(lang_code: String, current_lang: String = "") -> String:
	var resolved_lang := current_lang if not current_lang.is_empty() else _current_language
	var native_name = str(LANGUAGE_NATIVE_NAMES.get(lang_code, AVAILABLE_LANGUAGES.get(lang_code, lang_code)))
	var translated_name = get_text_for(resolved_lang, "language_name_%s" % lang_code)
	return "%s（%s）" % [native_name, translated_name]


func get_text_for(lang_code: String, key: String) -> String:
	var resolved_lang := lang_code if not lang_code.is_empty() else _current_language
	var current_translations: Dictionary = _translations.get(resolved_lang, {})
	if current_translations.has(key):
		return str(current_translations[key])

	if resolved_lang != "en":
		var english_translations: Dictionary = _translations.get("en", {})
		if english_translations.has(key):
			return str(english_translations[key])

	return key


func get_text(key: String) -> String:
	return get_text_for(_current_language, key)


static func translate(key: String) -> String:
	return get_instance().get_text(key)
