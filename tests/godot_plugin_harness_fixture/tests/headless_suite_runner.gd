extends SceneTree

const RuntimeBridgeContractTest = preload("res://tests/runtime_bridge_contract_test.gd")


func _initialize() -> void:
	call_deferred("_run_suite")


func _run_suite() -> void:
	var results: Array[Dictionary] = []
	var success := true
	var cases := [RuntimeBridgeContractTest.new()]
	for case in cases:
		var result: Dictionary = await case.run_case(self)
		results.append(result)
		if not bool(result.get("success", false)):
			success = false

	print(JSON.stringify({
		"success": success,
		"results": results
	}))
	quit(0 if success else 1)
