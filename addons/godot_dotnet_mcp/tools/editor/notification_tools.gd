@tool
extends "res://addons/godot_dotnet_mcp/tools/base_tools.gd"

## Editor notification tools for Godot MCP


func execute(ei, args: Dictionary) -> Dictionary:
	var action = args.get("action", "")
	var message = args.get("message", "")

	if message.is_empty():
		return _error("Message is required")

	match action:
		"toast":
			return _show_toast(ei, message, args.get("severity", "info"))
		"popup":
			return _show_popup(args.get("title", ""), message)
		"confirm":
			return _show_confirm(args.get("title", ""), message)
		_:
			return _error("Unknown action: %s" % action)


func _show_toast(ei, message: String, severity: String) -> Dictionary:
	if not ei:
		print("[Toast] %s: %s" % [severity, message])
		return _success({"method": "print"}, "Toast shown (via print)")

	match severity:
		"warning":
			push_warning(message)
		"error":
			push_error(message)
		_:
			print(message)

	return _success({
		"message": message,
		"severity": severity
	}, "Notification shown")


func _show_popup(title: String, message: String) -> Dictionary:
	print("[Popup] %s: %s" % [title, message])

	return _success({
		"title": title,
		"message": message
	}, "Popup shown (via console)")


func _show_confirm(title: String, message: String) -> Dictionary:
	print("[Confirm] %s: %s" % [title, message])

	return _success({
		"title": title,
		"message": message,
		"note": "Confirmation dialogs require user interaction"
	}, "Confirmation logged")
