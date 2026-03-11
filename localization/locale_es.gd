@tool
extends RefCounted

## Traducción al español

const TRANSLATIONS: Dictionary = {
	# Tab names
	"tab_server": "Servidor",
	"tab_tools": "Herramientas",
	"tab_config": "Config",

	# Header
	"title": "Godot MCP Server",
	"status_running": "Ejecutando",
	"status_stopped": "Detenido",

	# Server tab
	"server_status": "Estado del servidor",
	"endpoint": "Punto final:",
	"connections": "Conexiones:",
	"settings": "Ajustes",
	"port": "Puerto:",
	"auto_start": "Inicio automático",
	"debug_log": "Registro de depuración",
	"btn_start": "Iniciar",
	"btn_stop": "Detener",

	# About section
	"about": "Acerca de",
	"author": "Autor:",
	"wechat": "WeChat:",

	# Tools tab
	"tools_enabled": "Herramientas: %d/%d habilitadas",
	"btn_expand_all": "Expandir todo",
	"btn_collapse_all": "Contraer todo",
	"btn_select_all": "Seleccionar todo",
	"btn_deselect_all": "Deseleccionar todo",

	# Tool categories - Core
	"cat_scene": "Escena",
	"cat_node": "Nodo",
	"cat_script": "Script",
	"cat_resource": "Recurso",
	"cat_filesystem": "Sistema de archivos",
	"cat_project": "Proyecto",
	"cat_editor": "Editor",
	"cat_debug": "Depuración",
	"cat_animation": "Animación",

	# Tool categories - Visual
	"cat_material": "Material",
	"cat_shader": "Shader",
	"cat_lighting": "Iluminación",
	"cat_particle": "Partícula",

	# Tool categories - 2D
	"cat_tilemap": "TileMap",
	"cat_geometry": "Geometría",

	# Tool categories - Gameplay
	"cat_physics": "Física",
	"cat_navigation": "Navegación",
	"cat_audio": "Audio",

	# Tool categories - Utilities
	"cat_ui": "Interfaz",
	"cat_signal": "Señal",
	"cat_group": "Grupo",

	# Config tab - IDE section
	"ide_config": "Configuración IDE con un clic",
	"ide_config_desc": "Haga clic para escribir automáticamente el archivo de config, reinicie el cliente",
	"btn_one_click": "Configurar",
	"btn_copy": "Copiar",

	# Config tab - CLI section
	"cli_config": "Configuración de línea de comandos",
	"cli_config_desc": "Copie el comando y ejecútelo en la terminal",
	"config_scope": "Ámbito de config:",
	"scope_user": "Usuario (global)",
	"scope_project": "Proyecto (solo actual)",
	"btn_copy_cmd": "Copiar comando",

	# Messages
	"msg_config_success": "¡%s configurado con éxito!",
	"msg_config_failed": "Error de configuración",
	"msg_copied": "%s copiado al portapapeles",
	"msg_parse_error": "Error al analizar la configuración",
	"msg_dir_error": "No se puede crear el directorio: ",
	"msg_write_error": "No se puede escribir el archivo de configuración",

	# Language
	"language": "Idioma:",

	# ==================== Descripciones de herramientas ====================
	# Herramientas de escena
	"tool_scene_management_desc": "Abrir, guardar, crear y gestionar escenas",
	"tool_scene_hierarchy_desc": "Obtener estructura del árbol de escena y selección de nodos",
	"tool_scene_run_desc": "Ejecutar y probar escenas en el editor",

	# Herramientas de nodo
	"tool_node_query_desc": "Buscar e inspeccionar nodos por nombre, tipo o patrón",
	"tool_node_lifecycle_desc": "Crear, eliminar, duplicar e instanciar nodos",
	"tool_node_transform_desc": "Modificar posición, rotación y escala",
	"tool_node_property_desc": "Obtener y establecer cualquier propiedad de nodo",
	"tool_node_hierarchy_desc": "Gestionar relaciones padre-hijo y orden",
	"tool_node_signal_desc": "Conectar, desconectar y emitir señales",
	"tool_node_group_desc": "Añadir, eliminar y consultar grupos de nodos",
	"tool_node_process_desc": "Controlar modos de procesamiento de nodos",
	"tool_node_metadata_desc": "Obtener y establecer metadatos del nodo",
	"tool_node_call_desc": "Llamar dinámicamente métodos en nodos",
	"tool_node_visibility_desc": "Controlar visibilidad y capas de nodos",
	"tool_node_physics_desc": "Configurar propiedades físicas",

	# Herramientas de recurso
	"tool_resource_query_desc": "Buscar e inspeccionar recursos",
	"tool_resource_manage_desc": "Cargar, guardar y duplicar recursos",
	"tool_resource_texture_desc": "Gestionar recursos de textura",

	# Herramientas de proyecto
	"tool_project_info_desc": "Obtener información y rutas del proyecto",
	"tool_project_settings_desc": "Leer y modificar ajustes del proyecto",
	"tool_project_input_desc": "Gestionar mapeos de acciones de entrada",
	"tool_project_autoload_desc": "Gestionar singletons de autocarga",

	# Herramientas de script
	"tool_script_manage_desc": "Crear, leer y modificar scripts",
	"tool_script_attach_desc": "Adjuntar o separar scripts de nodos",
	"tool_script_edit_desc": "Añadir funciones, variables y señales",
	"tool_script_open_desc": "Abrir scripts en el editor",

	# Herramientas de editor
	"tool_editor_status_desc": "Obtener estado del editor e información de escena",
	"tool_editor_settings_desc": "Leer y modificar ajustes del editor",
	"tool_editor_undo_redo_desc": "Gestionar operaciones deshacer/rehacer",
	"tool_editor_notification_desc": "Mostrar notificaciones y diálogos del editor",
	"tool_editor_inspector_desc": "Controlar el panel inspector",
	"tool_editor_filesystem_desc": "Interactuar con el dock del sistema de archivos",
	"tool_editor_plugin_desc": "Buscar y gestionar plugins del editor",

	# Herramientas de depuración
	"tool_debug_log_desc": "Imprimir mensajes de depuración y errores",
	"tool_debug_performance_desc": "Monitorizar métricas de rendimiento",
	"tool_debug_profiler_desc": "Perfilar ejecución de código",
	"tool_debug_class_db_desc": "Consultar base de datos de clases de Godot",

	# Herramientas del sistema de archivos
	"tool_filesystem_directory_desc": "Crear, eliminar y listar directorios",
	"tool_filesystem_file_desc": "Leer, escribir y gestionar archivos",
	"tool_filesystem_json_desc": "Leer y escribir archivos JSON",
	"tool_filesystem_search_desc": "Buscar archivos por patrón",

	# Herramientas de animación
	"tool_animation_player_desc": "Controlar nodos AnimationPlayer",
	"tool_animation_animation_desc": "Crear y modificar animaciones",
	"tool_animation_track_desc": "Añadir y editar pistas de animación",
	"tool_animation_tween_desc": "Crear y controlar tweens",
	"tool_animation_animation_tree_desc": "Configurar árboles de animación",
	"tool_animation_state_machine_desc": "Gestionar máquinas de estados de animación",
	"tool_animation_blend_space_desc": "Configurar espacios de mezcla",
	"tool_animation_blend_tree_desc": "Configurar nodos de árbol de mezcla",

	# Herramientas de material
	"tool_material_material_desc": "Crear y modificar materiales",
	"tool_material_mesh_desc": "Gestionar recursos de malla",

	# Herramientas de shader
	"tool_shader_shader_desc": "Crear y editar shaders",
	"tool_shader_shader_material_desc": "Aplicar shaders a materiales",

	# Herramientas de iluminación
	"tool_lighting_light_desc": "Crear y configurar luces",
	"tool_lighting_environment_desc": "Configurar entorno mundial",
	"tool_lighting_sky_desc": "Configurar cielo y atmósfera",

	# Herramientas de partículas
	"tool_particle_particles_desc": "Crear y configurar sistemas de partículas",
	"tool_particle_particle_material_desc": "Configurar materiales de partículas",

	# Herramientas de tilemap
	"tool_tilemap_tileset_desc": "Crear y editar tilesets",
	"tool_tilemap_tilemap_desc": "Editar capas y celdas del tilemap",

	# Herramientas de geometría
	"tool_geometry_csg_desc": "Crear geometría sólida constructiva CSG",
	"tool_geometry_gridmap_desc": "Editar mapas de cuadrícula 3D",
	"tool_geometry_multimesh_desc": "Configurar instancias multi-malla",

	# Herramientas de física
	"tool_physics_physics_body_desc": "Crear y configurar cuerpos físicos",
	"tool_physics_collision_shape_desc": "Añadir y modificar formas de colisión",
	"tool_physics_physics_joint_desc": "Crear articulaciones y restricciones físicas",
	"tool_physics_physics_query_desc": "Realizar consultas físicas y raycasts",

	# Herramientas de navegación
	"tool_navigation_navigation_desc": "Configurar mallas y agentes de navegación",

	# Herramientas de audio
	"tool_audio_bus_desc": "Gestionar buses de audio y efectos",
	"tool_audio_player_desc": "Controlar reproducción de audio",

	# Herramientas de UI
	"tool_ui_theme_desc": "Crear y modificar temas de UI",
	"tool_ui_control_desc": "Configurar nodos de control",

	# Herramientas de señal
	"tool_signal_signal_desc": "Gestionar globalmente conexiones de señales",

	# Herramientas de grupo
	"tool_group_group_desc": "Buscar y gestionar globalmente grupos de nodos",
	"dialog_title": "Godot MCP",
	"server_state_label": "Estado:",
	"active_connections": "Conexiones activas:",
	"total_requests": "Solicitudes totales:",
	"total_connections_short": "conexiones",
	"last_request": "Última solicitud:",
	"last_request_none": "Todavía no hay solicitudes",
	"btn_restart": "Reiniciar",
	"btn_reload_plugin": "Recargar plugin por completo",
	"tool_profile": "Perfil:",
	"tool_profile_slim": "Ligero",
	"tool_profile_default": "Predeterminado",
	"tool_profile_full": "Completo",
	"tool_profile_slim_desc": "Activa solo las herramientas principales de inspección y edición más usadas en proyectos Godot.NET.",
	"tool_profile_default_desc": "Perfil recomendado para el día a día. Mantiene disponibles núcleo, jugabilidad, animación y UI.",
	"tool_profile_full_desc": "Activa todas las categorías de herramientas registradas.",
	"tool_profile_custom_desc": "Perfil personalizado: %s",
	"tool_profile_modified_desc": "La selección actual fue modificada. Usa Agregar para guardarla como perfil personalizado.",
	"tool_profile_save_title": "Guardar perfil de herramientas personalizado",
	"tool_profile_save_desc": "Guarda la selección actual de herramientas como un perfil reutilizable.",
	"tool_profile_name_placeholder": "Nombre del perfil",
	"tool_profile_name_required": "El nombre del perfil es obligatorio",
	"tool_profile_saved": "Perfil guardado: %s",
	"tool_profile_save_failed": "No se pudo guardar el perfil",
	"btn_add_profile": "Agregar",
	"btn_save_profile": "Guardar",
	"tools_server_unavailable": "Servidor no disponible. Revisa la salida del editor para errores de carga de scripts.",
	"tools_load_errors": "Se omitieron %d categorías de herramientas por errores de carga. Revisa la salida del editor.",
	"domain_core": "Núcleo",
	"domain_visual": "Visual",
	"domain_gameplay": "Jugabilidad",
	"domain_interface": "Interfaz",
	"domain_other": "Otros",
	"tool_scene_bindings_name": "Vinculaciones",
	"tool_scene_audit_name": "Auditoría",
	"tool_scene_management_name": "Gestión",
	"tool_scene_hierarchy_name": "Jerarquía",
	"tool_scene_run_name": "Ejecución",
	"tool_scene_bindings_desc": "Inspecciona las vinculaciones exportadas usadas por una escena",
	"tool_scene_audit_desc": "Informa problemas de escena derivados de vinculaciones exportadas",
	"tool_node_query_name": "Consulta",
	"tool_node_lifecycle_name": "Ciclo de vida",
	"tool_node_transform_name": "Transformación",
	"tool_node_property_name": "Propiedad",
	"tool_node_hierarchy_name": "Jerarquía",
	"tool_node_signal_name": "Señal",
	"tool_node_group_name": "Grupo",
	"tool_node_process_name": "Proceso",
	"tool_node_metadata_name": "Metadatos",
	"tool_node_call_name": "Llamada",
	"tool_node_visibility_name": "Visibilidad",
	"tool_node_physics_name": "Física",
	"tool_resource_query_name": "Consulta",
	"tool_resource_manage_name": "Gestionar",
	"tool_resource_texture_name": "Textura",
	"tool_project_info_name": "Información",
	"tool_project_settings_name": "Configuración",
	"tool_project_input_name": "Entrada",
	"tool_project_autoload_name": "Autoload",
	"tool_script_read_name": "Leer",
	"tool_script_open_name": "Abrir",
	"tool_script_inspect_name": "Inspeccionar",
	"tool_script_symbols_name": "Símbolos",
	"tool_script_exports_name": "Exports",
	"tool_script_edit_gd_name": "Editar GDScript",
	"tool_script_read_desc": "Lee archivos de script como texto plano",
	"tool_script_inspect_desc": "Analiza metadatos de scripts GDScript y C#",
	"tool_script_symbols_desc": "Lista clases, métodos, exports y enums detectados",
	"tool_script_exports_desc": "Lista los miembros exportados declarados por un script",
	"tool_script_edit_gd_desc": "Edita archivos GDScript con ayudas estructuradas",
	"tool_editor_status_name": "Estado",
	"tool_editor_settings_name": "Configuración",
	"tool_editor_undo_redo_name": "Deshacer/Rehacer",
	"tool_editor_notification_name": "Notificación",
	"tool_editor_inspector_name": "Inspector",
	"tool_editor_filesystem_name": "Archivos",
	"tool_editor_plugin_name": "Plugin",
	"tool_debug_log_name": "Registro",
	"tool_debug_performance_name": "Rendimiento",
	"tool_debug_profiler_name": "Perfilador",
	"tool_debug_class_db_name": "Base de clases",
	"tool_filesystem_directory_name": "Directorio",
	"tool_filesystem_file_name": "Archivo",
	"tool_filesystem_json_name": "JSON",
	"tool_filesystem_search_name": "Búsqueda",
	"tool_animation_player_name": "Player",
	"tool_animation_animation_name": "Animación",
	"tool_animation_track_name": "Pista",
	"tool_animation_tween_name": "Tween",
	"tool_animation_animation_tree_name": "Árbol de animación",
	"tool_animation_state_machine_name": "Máquina de estados",
	"tool_animation_blend_space_name": "Blend Space",
	"tool_animation_blend_tree_name": "Blend Tree",
	"tool_material_material_name": "Material",
	"tool_material_mesh_name": "Malla",
	"tool_shader_shader_name": "Shader",
	"tool_shader_shader_material_name": "Material de shader",
	"tool_lighting_light_name": "Luz",
	"tool_lighting_environment_name": "Entorno",
	"tool_lighting_sky_name": "Cielo",
	"tool_particle_particles_name": "Partículas",
	"tool_particle_particle_material_name": "Material de partículas",
	"tool_tilemap_tileset_name": "Tileset",
	"tool_tilemap_tilemap_name": "TileMap",
	"tool_geometry_csg_name": "CSG",
	"tool_geometry_gridmap_name": "GridMap",
	"tool_geometry_multimesh_name": "MultiMesh",
	"tool_physics_physics_body_name": "Cuerpo físico",
	"tool_physics_collision_shape_name": "Forma de colisión",
	"tool_physics_physics_joint_name": "Articulación física",
	"tool_physics_physics_query_name": "Consulta física",
	"tool_navigation_navigation_name": "Navegación",
	"tool_audio_bus_name": "Bus",
	"tool_audio_player_name": "Player",
	"tool_ui_theme_name": "Tema",
	"tool_ui_control_name": "Control",
	"tool_signal_signal_name": "Señal",
	"tool_group_group_name": "Grupo",
}


static func get_translations() -> Dictionary:
	return TRANSLATIONS
