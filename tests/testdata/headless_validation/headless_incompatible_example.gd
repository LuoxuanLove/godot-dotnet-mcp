extends CentralServerAttachService
# This would fail because it inherits from editor-bound service.


func run_case(_tree: SceneTree) -> Dictionary:
	return {
		"name": "headless_validation_incompatible_example",
		"success": true,
		"error": ""
	}
