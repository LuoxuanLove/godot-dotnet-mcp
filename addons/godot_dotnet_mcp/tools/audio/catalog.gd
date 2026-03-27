@tool
extends RefCounted


func get_tools() -> Array[Dictionary]:
	return [
		{
			"name": "bus",
			"description": """AUDIO BUS: Manage audio buses.

ACTIONS:
- list: List all audio buses
- get_info: Get info about a specific bus
- add: Add a new bus
- remove: Remove a bus (except Master)
- set_volume: Set bus volume in dB
- set_mute: Mute/unmute a bus
- set_solo: Solo/unsolo a bus
- set_bypass: Bypass/unbypass effects
- add_effect: Add an effect to a bus
- remove_effect: Remove an effect from a bus
- get_effect: Get effect info
- set_effect_enabled: Enable/disable an effect
""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list", "get_info", "add", "remove", "set_volume", "set_mute", "set_solo", "set_bypass", "add_effect", "remove_effect", "get_effect", "set_effect_enabled"],
						"description": "Bus action"
					},
					"bus": {
						"type": "string",
						"description": "Bus name or index"
					},
					"volume_db": {
						"type": "number",
						"description": "Volume in decibels"
					},
					"mute": {
						"type": "boolean",
						"description": "Mute state"
					},
					"solo": {
						"type": "boolean",
						"description": "Solo state"
					},
					"bypass": {
						"type": "boolean",
						"description": "Bypass effects"
					},
					"effect": {
						"type": "string",
						"description": "Effect class name"
					},
					"effect_index": {
						"type": "integer",
						"description": "Effect index on bus"
					},
					"enabled": {
						"type": "boolean",
						"description": "Effect enabled state"
					},
					"at_position": {
						"type": "integer",
						"description": "Position to insert effect"
					}
				},
				"required": ["action"]
			}
		},
		{
			"name": "player",
			"description": """AUDIO PLAYER: Control AudioStreamPlayer nodes.

ACTIONS:
- list: List all AudioStreamPlayer nodes in scene
- get_info: Get info about an audio player
- play: Start playing
- stop: Stop playing
- pause: Pause/unpause
- seek: Seek to position
- set_volume: Set volume in dB
- set_pitch: Set pitch scale
- set_bus: Set output bus
- set_stream: Set audio stream resource
""",
			"inputSchema": {
				"type": "object",
				"properties": {
					"action": {
						"type": "string",
						"enum": ["list", "get_info", "play", "stop", "pause", "seek", "set_volume", "set_pitch", "set_bus", "set_stream"],
						"description": "Player action"
					},
					"path": {
						"type": "string",
						"description": "AudioStreamPlayer node path"
					},
					"position": {
						"type": "number",
						"description": "Playback position in seconds"
					},
					"volume_db": {
						"type": "number",
						"description": "Volume in decibels"
					},
					"pitch_scale": {
						"type": "number",
						"description": "Pitch scale"
					},
					"bus": {
						"type": "string",
						"description": "Output bus name"
					},
					"stream": {
						"type": "string",
						"description": "AudioStream resource path"
					},
					"from_position": {
						"type": "number",
						"description": "Start position for play"
					},
					"paused": {
						"type": "boolean",
						"description": "Pause state"
					}
				},
				"required": ["action"]
			}
		}
	]
