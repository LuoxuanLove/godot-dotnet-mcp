@tool
extends RefCounted
class_name ClientConfigLauncherAdapter


func build_cli_invocation(script_path: String, arguments: PackedStringArray) -> Dictionary:
	if _is_windows_script(script_path):
		return {
			"command": "cmd.exe",
			"arguments": PackedStringArray(["/c", script_path]) + arguments
		}

	return {
		"command": script_path,
		"arguments": arguments
	}


func build_windows_cli_command_line(script_path: String, arguments: PackedStringArray) -> String:
	var quoted_args: Array[String] = []
	for argument in arguments:
		quoted_args.append(_quote_windows_argument(argument))

	if _is_windows_script(script_path):
		return "call %s %s" % [script_path, " ".join(quoted_args)]

	return "%s %s" % [script_path, " ".join(quoted_args)]


func _is_windows_script(script_path: String) -> bool:
	return script_path.to_lower().ends_with(".cmd") or script_path.to_lower().ends_with(".bat")


func _quote_windows_argument(argument: String) -> String:
	if argument.find(" ") != -1 or argument.find("\t") != -1:
		return '"%s"' % argument.replace('"', '\"')
	return argument
