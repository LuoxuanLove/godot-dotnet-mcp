extends RefCounted

# {"name": "tool_loader_idle_tick_budget_contracts"}

const ToolLoaderScript = preload("res://addons/godot_dotnet_mcp/tools/core/tool_loader.gd")


class FakeLifecycleService extends RefCounted:
	var tick_count := 0
	var tick_deltas: Array[float] = []

	func tick(delta: float, _context: Dictionary) -> void:
		tick_count += 1
		tick_deltas.append(delta)


class FakeLspDiagnosticsService extends RefCounted:
	var active := false

	func configure(_tool_loader) -> void:
		pass

	func has_active_request() -> bool:
		return active


func run_case(_tree: SceneTree) -> Dictionary:
	var loader = ToolLoaderScript.new()
	var lifecycle := FakeLifecycleService.new()
	var lsp := FakeLspDiagnosticsService.new()
	loader._lifecycle_service = lifecycle
	loader._lsp_diagnostics_service = lsp

	for _index in range(4):
		loader.tick(0.1)
	if lifecycle.tick_count != 0:
		return _failure("Idle loader tick should defer lifecycle work below the idle budget.", {
			"tick_count": lifecycle.tick_count,
			"deltas": lifecycle.tick_deltas
		})

	loader.tick(0.1)
	if lifecycle.tick_count != 1:
		return _failure("Idle loader tick should run once when accumulated delta reaches the idle budget.", {
			"tick_count": lifecycle.tick_count,
			"deltas": lifecycle.tick_deltas
		})
	if absf(float(lifecycle.tick_deltas[0]) - 0.5) > 0.001:
		return _failure("Idle loader tick should pass the accumulated idle delta to lifecycle work.", {
			"deltas": lifecycle.tick_deltas
		})

	lsp.active = true
	loader.tick(0.02)
	if lifecycle.tick_count != 1:
		return _failure("Active LSP loader tick should still defer below the active budget.", {
			"tick_count": lifecycle.tick_count,
			"deltas": lifecycle.tick_deltas
		})
	loader.tick(0.03)
	if lifecycle.tick_count != 2:
		return _failure("Active LSP loader tick should use the smaller active diagnostics budget.", {
			"tick_count": lifecycle.tick_count,
			"deltas": lifecycle.tick_deltas
		})
	if absf(float(lifecycle.tick_deltas[1]) - 0.05) > 0.001:
		return _failure("Active LSP tick should pass the accumulated active diagnostics delta.", {
			"deltas": lifecycle.tick_deltas
		})

	var performance: Dictionary = loader.get_performance_summary()
	if int(performance.get("lifecycle_tick_count", 0)) != 2:
		return _failure("Loader performance summary should expose lifecycle tick count.", performance)
	if absf(float(performance.get("lifecycle_tick_interval_seconds", 0.0)) - 0.05) > 0.001:
		return _failure("Loader performance summary should expose the latest active tick interval.", performance)

	return {
		"name": "tool_loader_idle_tick_budget_contracts",
		"success": true,
		"error": "",
		"details": {
			"tick_count": lifecycle.tick_count,
			"deltas": lifecycle.tick_deltas,
			"performance": performance
		}
	}


func _failure(message: String, details: Dictionary = {}) -> Dictionary:
	return {
		"name": "tool_loader_idle_tick_budget_contracts",
		"success": false,
		"error": message,
		"details": details
	}
