@tool
extends "res://addons/godot_dotnet_mcp/tools/editor/service_base.gd"


func execute(_tool_name: String, args: Dictionary) -> Dictionary:
	var action = str(args.get("action", ""))
	var message = str(args.get("message", ""))
	if message.is_empty():
		return _error("Message is required")

	match action:
		"toast":
			var severity := str(args.get("severity", "info"))
			match severity:
				"warning":
					push_warning(message)
				"error":
					push_error(message)
				_:
					print(message)
			return _success({"message": message, "severity": severity}, "Notification shown")
		"popup":
			print("[Popup] %s: %s" % [str(args.get("title", "")), message])
			return _success({"title": str(args.get("title", "")), "message": message}, "Popup shown (via console)")
		"confirm":
			print("[Confirm] %s: %s" % [str(args.get("title", "")), message])
			return _success({"title": str(args.get("title", "")), "message": message}, "Confirmation logged")
		_:
			return _error("Unknown action: %s" % action)
