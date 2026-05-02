const DOCK_TITLE: String = "Signal Checker"
const ERROR_COLOR: Color = Color(1, 0.45, 0.45)

# Toggled by the dock's Debug checkbox.
static var debug: bool = false

static func debug_log(msg: String) -> void:
	if debug:
		print("[SignalChecker] " + msg)
