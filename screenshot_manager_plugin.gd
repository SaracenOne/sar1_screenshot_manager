extends EditorPlugin
tool

var editor_interface: EditorInterface = null


func _init():
	print("Initialising ScreenshotManager plugin")


func _notification(p_notification: int):
	match p_notification:
		NOTIFICATION_PREDELETE:
			print("Destroying ScreenshotManager plugin")


func get_name() -> String:
	return "ScreenshotManager"


func _enter_tree() -> void:
	editor_interface = get_editor_interface()

	add_autoload_singleton(
		"ScreenshotManager", "res://addons/screenshot_manager/screenshot_manager.gd"
	)


func _exit_tree() -> void:
	remove_autoload_singleton("ScreenshotManager")
