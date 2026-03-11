@tool
extends RefCounted

## Русский перевод

const TRANSLATIONS: Dictionary = {
	# Tab names
	"tab_server": "Сервер",
	"tab_tools": "Инструменты",
	"tab_config": "Настройки",

	# Header
	"title": "Godot MCP Server",
	"status_running": "Работает",
	"status_stopped": "Остановлен",

	# Server tab
	"server_status": "Состояние сервера",
	"endpoint": "Адрес:",
	"connections": "Подключения:",
	"settings": "Настройки",
	"port": "Порт:",
	"auto_start": "Автозапуск",
	"debug_log": "Журнал отладки",
	"btn_start": "Запустить",
	"btn_stop": "Остановить",

	# About section
	"about": "О программе",
	"author": "Автор:",
	"wechat": "WeChat:",

	# Tools tab
	"tools_enabled": "Инструменты: %d/%d включено",
	"btn_expand_all": "Развернуть все",
	"btn_collapse_all": "Свернуть все",
	"btn_select_all": "Выбрать все",
	"btn_deselect_all": "Снять все",

	# Tool categories - Core
	"cat_scene": "Сцена",
	"cat_node": "Узел",
	"cat_script": "Скрипт",
	"cat_resource": "Ресурс",
	"cat_filesystem": "Файловая система",
	"cat_project": "Проект",
	"cat_editor": "Редактор",
	"cat_plugin": "Runtime плагина",
	"cat_debug": "Отладка",
	"cat_animation": "Анимация",

	# Tool categories - Visual
	"cat_material": "Материал",
	"cat_shader": "Шейдер",
	"cat_lighting": "Освещение",
	"cat_particle": "Частицы",

	# Tool categories - 2D
	"cat_tilemap": "Тайлмап",
	"cat_geometry": "Геометрия",

	# Tool categories - Gameplay
	"cat_physics": "Физика",
	"cat_navigation": "Навигация",
	"cat_audio": "Аудио",

	# Tool categories - Utilities
	"cat_ui": "Интерфейс",
	"cat_signal": "Сигнал",
	"cat_group": "Группа",

	# Config tab - IDE section
	"ide_config": "Настройка IDE в один клик",
	"ide_config_desc": "Нажмите для автоматической записи конфигурации, перезапустите клиент",
	"btn_one_click": "Настроить",
	"btn_copy": "Копировать",

	# Config tab - CLI section
	"cli_config": "Настройка командной строки",
	"cli_config_desc": "Скопируйте команду и выполните в терминале",
	"config_scope": "Область настройки:",
	"scope_user": "Пользователь (глобально)",
	"scope_project": "Проект (только текущий)",
	"btn_copy_cmd": "Копировать команду",

	# Messages
	"msg_config_success": "%s настроен успешно!",
	"msg_config_failed": "Ошибка настройки",
	"msg_copied": "%s скопировано в буфер обмена",
	"msg_parse_error": "Ошибка разбора конфигурации",
	"msg_dir_error": "Невозможно создать каталог: ",
	"msg_write_error": "Невозможно записать файл конфигурации",

	# Language
	"language": "Язык:",

	# ==================== Описания инструментов ====================
	# Инструменты сцены
	"tool_scene_management_desc": "Открытие, сохранение, создание и управление сценами",
	"tool_scene_hierarchy_desc": "Получение структуры дерева сцены и выбора узлов",
	"tool_scene_run_desc": "Запуск и тестирование сцен в редакторе",

	# Инструменты узлов
	"tool_node_query_desc": "Поиск и проверка узлов по имени, типу или шаблону",
	"tool_node_lifecycle_desc": "Создание, удаление, дублирование и инстанцирование узлов",
	"tool_node_transform_desc": "Изменение позиции, вращения и масштаба",
	"tool_node_property_desc": "Получение и установка любых свойств узла",
	"tool_node_hierarchy_desc": "Управление родительско-дочерними отношениями и порядком",
	"tool_node_signal_desc": "Подключение, отключение и отправка сигналов",
	"tool_node_group_desc": "Добавление, удаление и поиск групп узлов",
	"tool_node_process_desc": "Управление режимами обработки узлов",
	"tool_node_metadata_desc": "Получение и установка метаданных узла",
	"tool_node_call_desc": "Динамический вызов методов узлов",
	"tool_node_visibility_desc": "Управление видимостью и слоями узлов",
	"tool_node_physics_desc": "Настройка свойств физики",

	# Инструменты ресурсов
	"tool_resource_query_desc": "Поиск и проверка ресурсов",
	"tool_resource_manage_desc": "Загрузка, сохранение и дублирование ресурсов",
	"tool_resource_texture_desc": "Управление текстурными ресурсами",

	# Инструменты проекта
	"tool_project_info_desc": "Получение информации о проекте и путях",
	"tool_project_settings_desc": "Чтение и изменение настроек проекта",
	"tool_project_input_desc": "Управление сопоставлением действий ввода",
	"tool_project_autoload_desc": "Управление автозагружаемыми синглтонами",

	# Инструменты скриптов
	"tool_script_manage_desc": "Создание, чтение и изменение скриптов",
	"tool_script_attach_desc": "Прикрепление или открепление скриптов от узлов",
	"tool_script_edit_desc": "Добавление функций, переменных и сигналов",
	"tool_script_open_desc": "Открытие скриптов в редакторе",

	# Инструменты редактора
	"tool_editor_status_desc": "Получение состояния редактора и информации о сцене",
	"tool_editor_settings_desc": "Чтение и изменение настроек редактора",
	"tool_editor_undo_redo_desc": "Управление операциями отмены/повтора",
	"tool_editor_notification_desc": "Отображение уведомлений и диалогов редактора",
	"tool_editor_inspector_desc": "Управление панелью инспектора",
	"tool_editor_filesystem_desc": "Взаимодействие с панелью файловой системы",
	"tool_editor_plugin_desc": "Поиск и управление плагинами редактора",

	# Инструменты отладки
	"tool_debug_log_desc": "Вывод отладочных сообщений и ошибок",
	"tool_debug_performance_desc": "Мониторинг показателей производительности",
	"tool_debug_profiler_desc": "Профилирование выполнения кода",
	"tool_debug_class_db_desc": "Запрос базы данных классов Godot",

	# Инструменты файловой системы
	"tool_filesystem_directory_desc": "Создание, удаление и список каталогов",
	"tool_filesystem_file_desc": "Чтение, запись и управление файлами",
	"tool_filesystem_json_desc": "Чтение и запись JSON-файлов",
	"tool_filesystem_search_desc": "Поиск файлов по шаблону",

	# Инструменты анимации
	"tool_animation_player_desc": "Управление узлами AnimationPlayer",
	"tool_animation_animation_desc": "Создание и изменение анимаций",
	"tool_animation_track_desc": "Добавление и редактирование треков анимации",
	"tool_animation_tween_desc": "Создание и управление твинами",
	"tool_animation_animation_tree_desc": "Настройка и конфигурация деревьев анимации",
	"tool_animation_state_machine_desc": "Управление машинами состояний анимации",
	"tool_animation_blend_space_desc": "Настройка пространств смешивания",
	"tool_animation_blend_tree_desc": "Настройка узлов дерева смешивания",

	# Инструменты материалов
	"tool_material_material_desc": "Создание и изменение материалов",
	"tool_material_mesh_desc": "Управление ресурсами мешей",

	# Инструменты шейдеров
	"tool_shader_shader_desc": "Создание и редактирование шейдеров",
	"tool_shader_shader_material_desc": "Применение шейдеров к материалам",

	# Инструменты освещения
	"tool_lighting_light_desc": "Создание и настройка источников света",
	"tool_lighting_environment_desc": "Настройка мирового окружения",
	"tool_lighting_sky_desc": "Настройка неба и атмосферы",

	# Инструменты частиц
	"tool_particle_particles_desc": "Создание и настройка систем частиц",
	"tool_particle_particle_material_desc": "Настройка материалов частиц",

	# Инструменты тайлмапов
	"tool_tilemap_tileset_desc": "Создание и редактирование наборов тайлов",
	"tool_tilemap_tilemap_desc": "Редактирование слоёв и ячеек тайлмапа",

	# Инструменты геометрии
	"tool_geometry_csg_desc": "Создание CSG конструктивной твёрдотельной геометрии",
	"tool_geometry_gridmap_desc": "Редактирование 3D-сеточных карт",
	"tool_geometry_multimesh_desc": "Настройка экземпляров мультимешей",

	# Инструменты физики
	"tool_physics_physics_body_desc": "Создание и настройка физических тел",
	"tool_physics_collision_shape_desc": "Добавление и изменение форм столкновений",
	"tool_physics_physics_joint_desc": "Создание физических соединений и ограничений",
	"tool_physics_physics_query_desc": "Выполнение физических запросов и рейкастов",

	# Инструменты навигации
	"tool_navigation_navigation_desc": "Настройка навигационных мешей и агентов",

	# Инструменты аудио
	"tool_audio_bus_desc": "Управление аудиошинами и эффектами",
	"tool_audio_player_desc": "Управление воспроизведением аудио",

	# Инструменты UI
	"tool_ui_theme_desc": "Создание и изменение тем UI",
	"tool_ui_control_desc": "Настройка узлов управления",

	# Инструменты сигналов
	"tool_signal_signal_desc": "Глобальное управление соединениями сигналов",

	# Инструменты групп
	"tool_group_group_desc": "Глобальный поиск и управление группами узлов",
	"dialog_title": "Godot MCP",
	"server_state_label": "Состояние:",
	"active_connections": "Активные подключения:",
	"total_requests": "Всего запросов:",
	"total_connections_short": "подключения",
	"last_request": "Последний запрос:",
	"last_request_none": "Запросов пока не было",
	"btn_restart": "Перезапустить",
	"btn_reload_plugin": "Полностью перезагрузить плагин",
	"tool_profile": "Профиль:",
	"tool_profile_slim": "Минимальный",
	"tool_profile_default": "Стандартный",
	"tool_profile_full": "Полный",
	"tool_profile_slim_desc": "Включает только базовые инструменты проверки, редактирования и runtime плагина, которые чаще всего нужны в проектах Godot.NET.",
	"tool_profile_default_desc": "Рекомендуемый профиль для повседневной работы. Сохраняет базовые, plugin, игровые, визуальные/анимационные и UI-инструменты.",
	"tool_profile_full_desc": "Включает все зарегистрированные категории инструментов.",
	"tool_profile_custom_desc": "Пользовательский профиль: %s",
	"tool_profile_modified_desc": "Текущий выбор изменён. Используйте «Добавить», чтобы сохранить его как пользовательский профиль.",
	"tool_profile_save_title": "Сохранить пользовательский профиль инструментов",
	"tool_profile_save_desc": "Сохраняет текущий набор инструментов как повторно используемый профиль.",
	"tool_profile_name_placeholder": "Название профиля",
	"tool_profile_name_required": "Название профиля обязательно",
	"tool_profile_saved": "Профиль сохранён: %s",
	"tool_profile_save_failed": "Не удалось сохранить профиль",
	"btn_add_profile": "Добавить",
	"btn_save_profile": "Сохранить",
	"tools_server_unavailable": "Сервер недоступен. Проверьте вывод редактора на ошибки загрузки скриптов.",
	"tools_load_errors": "Пропущено %d категорий инструментов из-за ошибок загрузки скриптов. Подробности см. в выводе редактора.",
	"domain_core": "Основа",
	"domain_plugin": "Плагин",
	"domain_visual": "Визуал",
	"domain_gameplay": "Геймплей",
	"domain_interface": "Интерфейс",
	"domain_other": "Другое",
	"tool_scene_bindings_name": "Привязки",
	"tool_scene_audit_name": "Аудит",
	"tool_scene_management_name": "Управление",
	"tool_scene_hierarchy_name": "Иерархия",
	"tool_scene_run_name": "Запуск",
	"tool_scene_bindings_desc": "Проверяет экспортированные привязки скриптов, используемые сценой",
	"tool_scene_audit_desc": "Сообщает о проблемах сцены, выявленных на основе экспортированных привязок",
	"tool_node_query_name": "Поиск",
	"tool_node_lifecycle_name": "Жизненный цикл",
	"tool_node_transform_name": "Трансформация",
	"tool_node_property_name": "Свойство",
	"tool_node_hierarchy_name": "Иерархия",
	"tool_node_signal_name": "Сигнал",
	"tool_node_group_name": "Группа",
	"tool_node_process_name": "Обработка",
	"tool_node_metadata_name": "Метаданные",
	"tool_node_call_name": "Вызов",
	"tool_node_visibility_name": "Видимость",
	"tool_node_physics_name": "Физика",
	"tool_resource_query_name": "Поиск",
	"tool_resource_manage_name": "Управление",
	"tool_resource_texture_name": "Текстура",
	"tool_project_info_name": "Информация",
	"tool_project_settings_name": "Настройки",
	"tool_project_input_name": "Ввод",
	"tool_project_autoload_name": "Автозагрузка",
	"tool_script_read_name": "Чтение",
	"tool_script_open_name": "Открыть",
	"tool_script_inspect_name": "Анализ",
	"tool_script_symbols_name": "Символы",
	"tool_script_exports_name": "Экспорты",
	"tool_script_edit_gd_name": "Редактировать GDScript",
	"tool_script_read_desc": "Читает файлы скриптов как обычный текст",
	"tool_script_inspect_desc": "Анализирует метаданные скриптов GDScript и C#",
	"tool_script_symbols_desc": "Показывает найденные классы, методы, экспорты и перечисления",
	"tool_script_exports_desc": "Показывает экспортированные члены, объявленные в скрипте",
	"tool_script_edit_gd_desc": "Редактирует файлы GDScript с помощью структурированных помощников",
	"tool_editor_status_name": "Состояние",
	"tool_editor_settings_name": "Настройки",
	"tool_editor_undo_redo_name": "Отмена/повтор",
	"tool_editor_notification_name": "Уведомление",
	"tool_editor_inspector_name": "Инспектор",
	"tool_editor_filesystem_name": "Файловая система",
	"tool_editor_plugin_name": "Плагин",
	"tool_debug_log_name": "Журнал",
	"tool_debug_performance_name": "Производительность",
	"tool_debug_profiler_name": "Профайлер",
	"tool_debug_class_db_name": "БД классов",
	"tool_filesystem_directory_name": "Каталог",
	"tool_filesystem_file_name": "Файл",
	"tool_filesystem_json_name": "JSON",
	"tool_filesystem_search_name": "Поиск",
	"tool_animation_player_name": "Плеер",
	"tool_animation_animation_name": "Анимация",
	"tool_animation_track_name": "Трек",
	"tool_animation_tween_name": "Твин",
	"tool_animation_animation_tree_name": "Дерево анимации",
	"tool_animation_state_machine_name": "Машина состояний",
	"tool_animation_blend_space_name": "Пространство смешивания",
	"tool_animation_blend_tree_name": "Дерево смешивания",
	"tool_material_material_name": "Материал",
	"tool_material_mesh_name": "Сетка",
	"tool_shader_shader_name": "Шейдер",
	"tool_shader_shader_material_name": "Материал шейдера",
	"tool_lighting_light_name": "Свет",
	"tool_lighting_environment_name": "Окружение",
	"tool_lighting_sky_name": "Небо",
	"tool_particle_particles_name": "Частицы",
	"tool_particle_particle_material_name": "Материал частиц",
	"tool_tilemap_tileset_name": "Набор тайлов",
	"tool_tilemap_tilemap_name": "Тайлмап",
	"tool_geometry_csg_name": "CSG",
	"tool_geometry_gridmap_name": "GridMap",
	"tool_geometry_multimesh_name": "MultiMesh",
	"tool_physics_physics_body_name": "Физическое тело",
	"tool_physics_collision_shape_name": "Форма столкновения",
	"tool_physics_physics_joint_name": "Физический шарнир",
	"tool_physics_physics_query_name": "Физический запрос",
	"tool_navigation_navigation_name": "Навигация",
	"tool_audio_bus_name": "Шина",
	"tool_audio_player_name": "Плеер",
	"tool_ui_theme_name": "Тема",
	"tool_ui_control_name": "Элемент управления",
	"tool_signal_signal_name": "Сигнал",
	"tool_group_group_name": "Группа",
}


static func get_translations() -> Dictionary:
	return TRANSLATIONS
