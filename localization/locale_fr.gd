@tool
extends RefCounted

## Traduction française

const TRANSLATIONS: Dictionary = {
	# Tab names
	"tab_server": "Serveur",
	"tab_tools": "Outils",
	"tab_config": "Config",

	# Header
	"title": "Godot MCP Server",
	"status_running": "En cours",
	"status_stopped": "Arrêté",

	# Server tab
	"server_status": "État du serveur",
	"endpoint": "Point d'accès:",
	"connections": "Connexions:",
	"settings": "Paramètres",
	"port": "Port:",
	"auto_start": "Démarrage auto",
	"debug_log": "Journal de débogage",
	"btn_start": "Démarrer",
	"btn_stop": "Arrêter",

	# About section
	"about": "À propos",
	"author": "Auteur:",
	"wechat": "WeChat:",

	# Tools tab
	"tools_enabled": "Outils: %d/%d activés",
	"btn_expand_all": "Tout déplier",
	"btn_collapse_all": "Tout replier",
	"btn_select_all": "Tout sélectionner",
	"btn_deselect_all": "Tout désélectionner",

	# Tool categories - Core
	"cat_scene": "Scène",
	"cat_node": "Nœud",
	"cat_script": "Script",
	"cat_resource": "Ressource",
	"cat_filesystem": "Système de fichiers",
	"cat_project": "Projet",
	"cat_editor": "Éditeur",
	"cat_plugin": "Runtime du plugin",
	"cat_debug": "Débogage",
	"cat_animation": "Animation",

	# Tool categories - Visual
	"cat_material": "Matériau",
	"cat_shader": "Shader",
	"cat_lighting": "Éclairage",
	"cat_particle": "Particule",

	# Tool categories - 2D
	"cat_tilemap": "TileMap",
	"cat_geometry": "Géométrie",

	# Tool categories - Gameplay
	"cat_physics": "Physique",
	"cat_navigation": "Navigation",
	"cat_audio": "Audio",

	# Tool categories - Utilities
	"cat_ui": "Interface",
	"cat_signal": "Signal",
	"cat_group": "Groupe",

	# Config tab - IDE section
	"ide_config": "Configuration IDE en un clic",
	"ide_config_desc": "Cliquez pour écrire automatiquement le fichier de config, redémarrez le client",
	"btn_one_click": "Configurer",
	"btn_copy": "Copier",

	# Config tab - CLI section
	"cli_config": "Configuration ligne de commande",
	"cli_config_desc": "Copiez la commande et exécutez dans le terminal",
	"config_scope": "Portée de la config:",
	"scope_user": "Utilisateur (global)",
	"scope_project": "Projet (actuel uniquement)",
	"btn_copy_cmd": "Copier la commande",

	# Messages
	"msg_config_success": "%s configuré avec succès!",
	"msg_config_failed": "Échec de la configuration",
	"msg_copied": "%s copié dans le presse-papiers",
	"msg_parse_error": "Erreur d'analyse de la configuration",
	"msg_dir_error": "Impossible de créer le répertoire: ",
	"msg_write_error": "Impossible d'écrire le fichier de configuration",

	# Language
	"language": "Langue:",

	# ==================== Descriptions des outils ====================
	# Outils de scène
	"tool_scene_management_desc": "Ouvrir, enregistrer, créer et gérer les scènes",
	"tool_scene_hierarchy_desc": "Obtenir la structure de l'arbre de scène et la sélection des nœuds",
	"tool_scene_run_desc": "Exécuter et tester les scènes dans l'éditeur",

	# Outils de nœud
	"tool_node_query_desc": "Rechercher et inspecter les nœuds par nom, type ou motif",
	"tool_node_lifecycle_desc": "Créer, supprimer, dupliquer et instancier des nœuds",
	"tool_node_transform_desc": "Modifier la position, rotation et échelle",
	"tool_node_property_desc": "Obtenir et définir toute propriété de nœud",
	"tool_node_hierarchy_desc": "Gérer les relations parent-enfant et l'ordre",
	"tool_node_signal_desc": "Connecter, déconnecter et émettre des signaux",
	"tool_node_group_desc": "Ajouter, supprimer et rechercher des groupes de nœuds",
	"tool_node_process_desc": "Contrôler les modes de traitement des nœuds",
	"tool_node_metadata_desc": "Obtenir et définir les métadonnées du nœud",
	"tool_node_call_desc": "Appeler dynamiquement des méthodes sur les nœuds",
	"tool_node_visibility_desc": "Contrôler la visibilité et les calques des nœuds",
	"tool_node_physics_desc": "Configurer les propriétés physiques",

	# Outils de ressource
	"tool_resource_query_desc": "Rechercher et inspecter les ressources",
	"tool_resource_manage_desc": "Charger, enregistrer et dupliquer les ressources",
	"tool_resource_texture_desc": "Gérer les ressources de texture",

	# Outils de projet
	"tool_project_info_desc": "Obtenir les informations et chemins du projet",
	"tool_project_settings_desc": "Lire et modifier les paramètres du projet",
	"tool_project_input_desc": "Gérer les mappages d'actions d'entrée",
	"tool_project_autoload_desc": "Gérer les singletons autoload",

	# Outils de script
	"tool_script_manage_desc": "Créer, lire et modifier des scripts",
	"tool_script_attach_desc": "Attacher ou détacher des scripts des nœuds",
	"tool_script_edit_desc": "Ajouter des fonctions, variables et signaux",
	"tool_script_open_desc": "Ouvrir des scripts dans l'éditeur",

	# Outils d'éditeur
	"tool_editor_status_desc": "Obtenir l'état de l'éditeur et les infos de scène",
	"tool_editor_settings_desc": "Lire et modifier les paramètres de l'éditeur",
	"tool_editor_undo_redo_desc": "Gérer les opérations annuler/rétablir",
	"tool_editor_notification_desc": "Afficher les notifications et dialogues de l'éditeur",
	"tool_editor_inspector_desc": "Contrôler le panneau inspecteur",
	"tool_editor_filesystem_desc": "Interagir avec le dock du système de fichiers",
	"tool_editor_plugin_desc": "Rechercher et gérer les plugins de l'éditeur",

	# Outils de débogage
	"tool_debug_log_desc": "Afficher les messages de débogage et erreurs",
	"tool_debug_performance_desc": "Surveiller les métriques de performance",
	"tool_debug_profiler_desc": "Profiler l'exécution du code",
	"tool_debug_class_db_desc": "Interroger la base de données des classes Godot",

	# Outils du système de fichiers
	"tool_filesystem_directory_desc": "Créer, supprimer et lister les répertoires",
	"tool_filesystem_file_desc": "Lire, écrire et gérer les fichiers",
	"tool_filesystem_json_desc": "Lire et écrire des fichiers JSON",
	"tool_filesystem_search_desc": "Rechercher des fichiers par motif",

	# Outils d'animation
	"tool_animation_player_desc": "Contrôler les nœuds AnimationPlayer",
	"tool_animation_animation_desc": "Créer et modifier des animations",
	"tool_animation_track_desc": "Ajouter et modifier des pistes d'animation",
	"tool_animation_tween_desc": "Créer et contrôler des tweens",
	"tool_animation_animation_tree_desc": "Configurer les arbres d'animation",
	"tool_animation_state_machine_desc": "Gérer les machines à états d'animation",
	"tool_animation_blend_space_desc": "Configurer les espaces de mélange",
	"tool_animation_blend_tree_desc": "Configurer les nœuds d'arbre de mélange",

	# Outils de matériau
	"tool_material_material_desc": "Créer et modifier des matériaux",
	"tool_material_mesh_desc": "Gérer les ressources de maillage",

	# Outils de shader
	"tool_shader_shader_desc": "Créer et modifier des shaders",
	"tool_shader_shader_material_desc": "Appliquer des shaders aux matériaux",

	# Outils d'éclairage
	"tool_lighting_light_desc": "Créer et configurer des lumières",
	"tool_lighting_environment_desc": "Configurer l'environnement mondial",
	"tool_lighting_sky_desc": "Configurer le ciel et l'atmosphère",

	# Outils de particules
	"tool_particle_particles_desc": "Créer et configurer des systèmes de particules",
	"tool_particle_particle_material_desc": "Configurer les matériaux de particules",

	# Outils de tilemap
	"tool_tilemap_tileset_desc": "Créer et modifier des tilesets",
	"tool_tilemap_tilemap_desc": "Modifier les calques et cellules du tilemap",

	# Outils de géométrie
	"tool_geometry_csg_desc": "Créer de la géométrie CSG constructive",
	"tool_geometry_gridmap_desc": "Modifier les cartes de grille 3D",
	"tool_geometry_multimesh_desc": "Configurer les instances multi-maillage",

	# Outils de physique
	"tool_physics_physics_body_desc": "Créer et configurer des corps physiques",
	"tool_physics_collision_shape_desc": "Ajouter et modifier des formes de collision",
	"tool_physics_physics_joint_desc": "Créer des joints et contraintes physiques",
	"tool_physics_physics_query_desc": "Effectuer des requêtes physiques et raycasts",

	# Outils de navigation
	"tool_navigation_navigation_desc": "Configurer les maillages et agents de navigation",

	# Outils audio
	"tool_audio_bus_desc": "Gérer les bus audio et les effets",
	"tool_audio_player_desc": "Contrôler la lecture audio",

	# Outils UI
	"tool_ui_theme_desc": "Créer et modifier des thèmes UI",
	"tool_ui_control_desc": "Configurer les nœuds de contrôle",

	# Outils de signal
	"tool_signal_signal_desc": "Gérer globalement les connexions de signaux",

	# Outils de groupe
	"tool_group_group_desc": "Rechercher et gérer globalement les groupes de nœuds",
	"dialog_title": "Godot MCP",
	"server_state_label": "État :",
	"active_connections": "Connexions actives :",
	"total_requests": "Requêtes totales :",
	"total_connections_short": "connexions",
	"last_request": "Dernière requête :",
	"last_request_none": "Aucune requête pour le moment",
	"btn_restart": "Redémarrer",
	"btn_reload_plugin": "Recharger complètement le plugin",
	"tool_profile": "Profil :",
	"tool_profile_slim": "Léger",
	"tool_profile_default": "Par défaut",
	"tool_profile_full": "Complet",
	"tool_profile_slim_desc": "Active seulement les outils de base d'inspection, d'édition et de runtime plugin les plus utilisés dans les projets Godot.NET.",
	"tool_profile_default_desc": "Profil recommandé au quotidien. Conserve les outils de base, plugin, gameplay, visuel/animation et interface.",
	"tool_profile_full_desc": "Active toutes les catégories d'outils enregistrées.",
	"tool_profile_custom_desc": "Profil personnalisé : %s",
	"tool_profile_modified_desc": "La sélection actuelle a été modifiée. Utilisez Ajouter pour l'enregistrer comme profil personnalisé.",
	"tool_profile_save_title": "Enregistrer un profil d'outils personnalisé",
	"tool_profile_save_desc": "Enregistre la sélection actuelle d'outils comme profil réutilisable.",
	"tool_profile_name_placeholder": "Nom du profil",
	"tool_profile_name_required": "Le nom du profil est requis",
	"tool_profile_saved": "Profil enregistré : %s",
	"tool_profile_save_failed": "Échec de l'enregistrement du profil",
	"btn_add_profile": "Ajouter",
	"btn_save_profile": "Enregistrer",
	"tools_server_unavailable": "Serveur indisponible. Consultez la sortie de l'éditeur pour les erreurs de chargement des scripts.",
	"tools_load_errors": "%d catégories d'outils ont été ignorées à cause d'erreurs de chargement. Voir la sortie de l'éditeur.",
	"domain_core": "Cœur",
	"domain_plugin": "Plugin",
	"domain_visual": "Visuel",
	"domain_gameplay": "Gameplay",
	"domain_interface": "Interface",
	"domain_other": "Autre",
	"tool_scene_bindings_name": "Liaisons",
	"tool_scene_audit_name": "Audit",
	"tool_scene_management_name": "Gestion",
	"tool_scene_hierarchy_name": "Hiérarchie",
	"tool_scene_run_name": "Exécution",
	"tool_scene_bindings_desc": "Inspecte les liaisons de scripts exportés utilisées par une scène",
	"tool_scene_audit_desc": "Signale les problèmes de scène déduits des liaisons exportées",
	"tool_node_query_name": "Recherche",
	"tool_node_lifecycle_name": "Cycle de vie",
	"tool_node_transform_name": "Transformation",
	"tool_node_property_name": "Propriété",
	"tool_node_hierarchy_name": "Hiérarchie",
	"tool_node_signal_name": "Signal",
	"tool_node_group_name": "Groupe",
	"tool_node_process_name": "Traitement",
	"tool_node_metadata_name": "Métadonnées",
	"tool_node_call_name": "Appel",
	"tool_node_visibility_name": "Visibilité",
	"tool_node_physics_name": "Physique",
	"tool_resource_query_name": "Recherche",
	"tool_resource_manage_name": "Gestion",
	"tool_resource_texture_name": "Texture",
	"tool_project_info_name": "Infos",
	"tool_project_settings_name": "Paramètres",
	"tool_project_input_name": "Entrée",
	"tool_project_autoload_name": "Autoload",
	"tool_script_read_name": "Lire",
	"tool_script_open_name": "Ouvrir",
	"tool_script_inspect_name": "Inspecter",
	"tool_script_symbols_name": "Symboles",
	"tool_script_exports_name": "Exports",
	"tool_script_edit_gd_name": "Éditer GDScript",
	"tool_script_read_desc": "Lit les fichiers de script en texte brut",
	"tool_script_inspect_desc": "Analyse les métadonnées des scripts GDScript et C#",
	"tool_script_symbols_desc": "Liste les classes, méthodes, exports et énumérations détectés",
	"tool_script_exports_desc": "Liste les membres exportés déclarés par un script",
	"tool_script_edit_gd_desc": "Édite les fichiers GDScript avec des assistants structurés",
	"tool_editor_status_name": "État",
	"tool_editor_settings_name": "Paramètres",
	"tool_editor_undo_redo_name": "Annuler/Rétablir",
	"tool_editor_notification_name": "Notification",
	"tool_editor_inspector_name": "Inspecteur",
	"tool_editor_filesystem_name": "Fichiers",
	"tool_editor_plugin_name": "Plugin",
	"tool_debug_log_name": "Journal",
	"tool_debug_performance_name": "Performance",
	"tool_debug_profiler_name": "Profileur",
	"tool_debug_class_db_name": "Base de classes",
	"tool_filesystem_directory_name": "Répertoire",
	"tool_filesystem_file_name": "Fichier",
	"tool_filesystem_json_name": "JSON",
	"tool_filesystem_search_name": "Recherche",
	"tool_animation_player_name": "Lecteur",
	"tool_animation_animation_name": "Animation",
	"tool_animation_track_name": "Piste",
	"tool_animation_tween_name": "Tween",
	"tool_animation_animation_tree_name": "Arbre d'animation",
	"tool_animation_state_machine_name": "Machine à états",
	"tool_animation_blend_space_name": "Blend Space",
	"tool_animation_blend_tree_name": "Blend Tree",
	"tool_material_material_name": "Matériau",
	"tool_material_mesh_name": "Maillage",
	"tool_shader_shader_name": "Shader",
	"tool_shader_shader_material_name": "Matériau shader",
	"tool_lighting_light_name": "Lumière",
	"tool_lighting_environment_name": "Environnement",
	"tool_lighting_sky_name": "Ciel",
	"tool_particle_particles_name": "Particules",
	"tool_particle_particle_material_name": "Matériau de particules",
	"tool_tilemap_tileset_name": "Tileset",
	"tool_tilemap_tilemap_name": "TileMap",
	"tool_geometry_csg_name": "CSG",
	"tool_geometry_gridmap_name": "GridMap",
	"tool_geometry_multimesh_name": "MultiMesh",
	"tool_physics_physics_body_name": "Corps physique",
	"tool_physics_collision_shape_name": "Forme de collision",
	"tool_physics_physics_joint_name": "Joint physique",
	"tool_physics_physics_query_name": "Requête physique",
	"tool_navigation_navigation_name": "Navigation",
	"tool_audio_bus_name": "Bus",
	"tool_audio_player_name": "Lecteur",
	"tool_ui_theme_name": "Thème",
	"tool_ui_control_name": "Contrôle",
	"tool_signal_signal_name": "Signal",
	"tool_group_group_name": "Groupe",
}


static func get_translations() -> Dictionary:
	return TRANSLATIONS
