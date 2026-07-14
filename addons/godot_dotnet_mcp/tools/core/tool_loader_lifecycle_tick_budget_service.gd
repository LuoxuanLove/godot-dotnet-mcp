@tool
extends RefCounted

const IDLE_LIFECYCLE_TICK_INTERVAL_SECONDS := 0.5
const ACTIVE_LSP_LIFECYCLE_TICK_INTERVAL_SECONDS := 0.05
const MAX_LIFECYCLE_TICK_DELTA_SECONDS := 2.0

var _lifecycle_tick_accumulator := 0.0


func reset() -> void:
	_lifecycle_tick_accumulator = 0.0


func accumulate(delta: float, has_active_lsp_request: bool) -> Dictionary:
	_lifecycle_tick_accumulator = minf(
		_lifecycle_tick_accumulator + maxf(delta, 0.0),
		MAX_LIFECYCLE_TICK_DELTA_SECONDS
	)
	var interval := resolve_interval_seconds(has_active_lsp_request)
	if _lifecycle_tick_accumulator < interval:
		return {
			"should_tick": false,
			"interval_seconds": interval,
			"tick_delta_seconds": 0.0,
			"accumulator_seconds": _lifecycle_tick_accumulator
		}
	var tick_delta := _lifecycle_tick_accumulator
	_lifecycle_tick_accumulator = 0.0
	return {
		"should_tick": true,
		"interval_seconds": interval,
		"tick_delta_seconds": tick_delta,
		"accumulator_seconds": _lifecycle_tick_accumulator
	}


func resolve_interval_seconds(has_active_lsp_request: bool) -> float:
	return ACTIVE_LSP_LIFECYCLE_TICK_INTERVAL_SECONDS if has_active_lsp_request else IDLE_LIFECYCLE_TICK_INTERVAL_SECONDS


func record_performance(performance: Dictionary, elapsed_ms: float, interval_seconds: float, tick_delta: float) -> void:
	performance["lifecycle_tick_count"] = int(performance.get("lifecycle_tick_count", 0)) + 1
	performance["lifecycle_tick_last_ms"] = elapsed_ms
	performance["lifecycle_tick_max_ms"] = maxf(float(performance.get("lifecycle_tick_max_ms", 0.0)), elapsed_ms)
	performance["lifecycle_tick_interval_seconds"] = interval_seconds
	performance["lifecycle_tick_delta_seconds"] = tick_delta
