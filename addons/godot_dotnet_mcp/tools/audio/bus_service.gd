@tool
extends "res://addons/godot_dotnet_mcp/tools/audio/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action := str(args.get("action", ""))
	match action:
		"list":
			return _list_buses()
		"get_info":
			return _get_bus_info(args.get("bus", "Master"))
		"add":
			return _add_bus(str(args.get("bus", "NewBus")))
		"remove":
			return _remove_bus(args.get("bus", ""))
		"set_volume":
			return _set_bus_volume(args.get("bus", "Master"), float(args.get("volume_db", 0.0)))
		"set_mute":
			return _set_bus_mute(args.get("bus", "Master"), bool(args.get("mute", false)))
		"set_solo":
			return _set_bus_solo(args.get("bus", "Master"), bool(args.get("solo", false)))
		"set_bypass":
			return _set_bus_bypass(args.get("bus", "Master"), bool(args.get("bypass", false)))
		"add_effect":
			return _add_bus_effect(args.get("bus", "Master"), str(args.get("effect", "")), int(args.get("at_position", -1)))
		"remove_effect":
			return _remove_bus_effect(args.get("bus", "Master"), int(args.get("effect_index", 0)))
		"get_effect":
			return _get_bus_effect(args.get("bus", "Master"), int(args.get("effect_index", 0)))
		"set_effect_enabled":
			return _set_effect_enabled(args.get("bus", "Master"), int(args.get("effect_index", 0)), bool(args.get("enabled", true)))
		_:
			return _error("Unknown action: %s" % action)


func _list_buses() -> Dictionary:
	var buses: Array[Dictionary] = []

	for i in range(AudioServer.bus_count):
		var bus_name := AudioServer.get_bus_name(i)
		buses.append({
			"index": i,
			"name": bus_name,
			"volume_db": AudioServer.get_bus_volume_db(i),
			"mute": AudioServer.is_bus_mute(i),
			"solo": AudioServer.is_bus_solo(i),
			"bypass": AudioServer.is_bus_bypassing_effects(i),
			"effect_count": AudioServer.get_bus_effect_count(i),
			"send": AudioServer.get_bus_send(i)
		})

	return _success({
		"count": buses.size(),
		"buses": buses
	})


func _get_bus_info(bus) -> Dictionary:
	var idx := _get_bus_index(bus)
	if idx < 0:
		return _error("Bus not found: %s" % str(bus))

	var info := {
		"index": idx,
		"name": AudioServer.get_bus_name(idx),
		"volume_db": AudioServer.get_bus_volume_db(idx),
		"mute": AudioServer.is_bus_mute(idx),
		"solo": AudioServer.is_bus_solo(idx),
		"bypass": AudioServer.is_bus_bypassing_effects(idx),
		"send": AudioServer.get_bus_send(idx),
		"peak_left": AudioServer.get_bus_peak_volume_left_db(idx, 0),
		"peak_right": AudioServer.get_bus_peak_volume_right_db(idx, 0)
	}

	var effects: Array[Dictionary] = []
	for i in range(AudioServer.get_bus_effect_count(idx)):
		var effect = AudioServer.get_bus_effect(idx, i)
		effects.append({
			"index": i,
			"type": str(effect.get_class()) if effect else "null",
			"enabled": AudioServer.is_bus_effect_enabled(idx, i)
		})
	info["effects"] = effects

	return _success(info)


func _add_bus(bus_name: String) -> Dictionary:
	if bus_name.is_empty():
		return _error("Bus name is required")

	for i in range(AudioServer.bus_count):
		if AudioServer.get_bus_name(i) == bus_name:
			return _error("Bus already exists: %s" % bus_name)

	var new_idx := AudioServer.bus_count
	AudioServer.add_bus()
	AudioServer.set_bus_name(new_idx, bus_name)

	return _success({
		"index": new_idx,
		"name": bus_name
	}, "Bus created")


func _remove_bus(bus) -> Dictionary:
	var idx := _get_bus_index(bus)
	if idx < 0:
		return _error("Bus not found: %s" % str(bus))
	if idx == 0:
		return _error("Cannot remove Master bus")

	var bus_name := AudioServer.get_bus_name(idx)
	AudioServer.remove_bus(idx)

	return _success({
		"removed": bus_name
	}, "Bus removed")


func _set_bus_volume(bus, volume_db: float) -> Dictionary:
	var idx := _get_bus_index(bus)
	if idx < 0:
		return _error("Bus not found: %s" % str(bus))

	AudioServer.set_bus_volume_db(idx, volume_db)
	return _success({
		"bus": AudioServer.get_bus_name(idx),
		"volume_db": volume_db
	}, "Volume set")


func _set_bus_mute(bus, mute: bool) -> Dictionary:
	var idx := _get_bus_index(bus)
	if idx < 0:
		return _error("Bus not found: %s" % str(bus))

	AudioServer.set_bus_mute(idx, mute)
	return _success({
		"bus": AudioServer.get_bus_name(idx),
		"mute": mute
	}, "Mute %s" % ("enabled" if mute else "disabled"))


func _set_bus_solo(bus, solo: bool) -> Dictionary:
	var idx := _get_bus_index(bus)
	if idx < 0:
		return _error("Bus not found: %s" % str(bus))

	AudioServer.set_bus_solo(idx, solo)
	return _success({
		"bus": AudioServer.get_bus_name(idx),
		"solo": solo
	}, "Solo %s" % ("enabled" if solo else "disabled"))


func _set_bus_bypass(bus, bypass: bool) -> Dictionary:
	var idx := _get_bus_index(bus)
	if idx < 0:
		return _error("Bus not found: %s" % str(bus))

	AudioServer.set_bus_bypass_effects(idx, bypass)
	return _success({
		"bus": AudioServer.get_bus_name(idx),
		"bypass": bypass
	}, "Bypass %s" % ("enabled" if bypass else "disabled"))


func _add_bus_effect(bus, effect_type: String, at_position: int) -> Dictionary:
	var idx := _get_bus_index(bus)
	if idx < 0:
		return _error("Bus not found: %s" % str(bus))
	if effect_type.is_empty():
		return _error("Effect type is required")

	var effect = ClassDB.instantiate(effect_type)
	if effect == null or not effect is AudioEffect:
		return _error("Invalid effect type: %s" % effect_type)

	if at_position < 0:
		at_position = AudioServer.get_bus_effect_count(idx)

	AudioServer.add_bus_effect(idx, effect, at_position)
	return _success({
		"bus": AudioServer.get_bus_name(idx),
		"effect": effect_type,
		"position": at_position
	}, "Effect added")


func _remove_bus_effect(bus, effect_index: int) -> Dictionary:
	var idx := _get_bus_index(bus)
	if idx < 0:
		return _error("Bus not found: %s" % str(bus))
	if effect_index < 0 or effect_index >= AudioServer.get_bus_effect_count(idx):
		return _error("Invalid effect index: %d" % effect_index)

	var effect = AudioServer.get_bus_effect(idx, effect_index)
	var effect_type := str(effect.get_class()) if effect else "unknown"
	AudioServer.remove_bus_effect(idx, effect_index)

	return _success({
		"bus": AudioServer.get_bus_name(idx),
		"removed_effect": effect_type,
		"index": effect_index
	}, "Effect removed")


func _get_bus_effect(bus, effect_index: int) -> Dictionary:
	var idx := _get_bus_index(bus)
	if idx < 0:
		return _error("Bus not found: %s" % str(bus))
	if effect_index < 0 or effect_index >= AudioServer.get_bus_effect_count(idx):
		return _error("Invalid effect index: %d" % effect_index)

	var effect = AudioServer.get_bus_effect(idx, effect_index)
	if effect == null:
		return _error("Effect is null")

	var info := {
		"bus": AudioServer.get_bus_name(idx),
		"index": effect_index,
		"type": str(effect.get_class()),
		"enabled": AudioServer.is_bus_effect_enabled(idx, effect_index)
	}

	var properties := {}
	for prop in effect.get_property_list():
		var prop_name := str(prop.name)
		if not prop_name.begins_with("_") and prop.usage & PROPERTY_USAGE_EDITOR:
			properties[prop_name] = effect.get(prop_name)
	info["properties"] = properties

	return _success(info)


func _set_effect_enabled(bus, effect_index: int, enabled: bool) -> Dictionary:
	var idx := _get_bus_index(bus)
	if idx < 0:
		return _error("Bus not found: %s" % str(bus))
	if effect_index < 0 or effect_index >= AudioServer.get_bus_effect_count(idx):
		return _error("Invalid effect index: %d" % effect_index)

	AudioServer.set_bus_effect_enabled(idx, effect_index, enabled)
	return _success({
		"bus": AudioServer.get_bus_name(idx),
		"effect_index": effect_index,
		"enabled": enabled
	}, "Effect %s" % ("enabled" if enabled else "disabled"))
