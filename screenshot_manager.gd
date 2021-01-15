tool
extends Node

var pending: bool = false
var image_thread: Thread = Thread.new()

signal screenshot_requested(p_info, p_callback)
signal screenshot_saved(p_path)
signal screenshot_failed(p_path, p_err)

##############
# Screenshot #
##############

# OpenGL backend requires screenshots to be flipped on the Y-axis
static func apply_screenshot_flip(p_image: Image) -> Image:
	p_image.flip_y()
	return p_image
	
static func _get_screenshot_path_and_prefix(p_screenshot_directory: String) -> String:
	return "%s/screenshot_" % p_screenshot_directory
	
static func _incremental_screenshot(p_info: Dictionary) -> Dictionary:
	var file: File = File.new()
	var err: int = OK
	var path: String = ""
	
	var screenshot_directory: String = p_info["screenshot_directory"]
	
	var screenshot_number: int = 0
	var screenshot_path_and_prefix: String = _get_screenshot_path_and_prefix(screenshot_directory)
	while((file.file_exists(screenshot_path_and_prefix + str(screenshot_number).pad_zeros(4) + ".png"))):
		screenshot_number += 1
	
	if(screenshot_number <= 9999):
		path = screenshot_path_and_prefix + str(screenshot_number).pad_zeros(4) + ".png"
	else:
		err = FAILED
	
	return {"error":err, "path":path}
	
static func _date_and_time_screenshot(p_info: Dictionary) -> Dictionary:
	var file: File = File.new()
	var err: int = OK
	var path: String = ""
	
	var screenshot_directory: String = p_info["screenshot_directory"]
	
	var screenshot_number: int = 0
	var screenshot_path_and_prefix: String = _get_screenshot_path_and_prefix(screenshot_directory)
	var time: Dictionary = OS.get_datetime()
	var date_time_string: String = "%s_%02d_%02d_%02d%02d%02d" % [
		time['year'],
		time['month'],
		time['day'],
		time['hour'],
		time['minute'],
		time['second']]
	
	if(!file.file_exists(screenshot_path_and_prefix + date_time_string + ".png")):
		path = screenshot_path_and_prefix + date_time_string + ".png"
	else:
		err = ERR_FILE_ALREADY_IN_USE
	
	return {"error":err, "path":path}

func _unsafe_serialize_screenshot(p_userdata: Dictionary) -> Dictionary:
	var info: Dictionary = p_userdata["info"]
	var image: Image = p_userdata["image"]
	
	var screenshot_path_callback: FuncRef = info["screenshot_path_callback"]
	var error: int = FAILED
	
	var result: Dictionary = screenshot_path_callback.call_func(info)
	error = result["error"]
	if error == OK:
		error = apply_screenshot_flip(image).save_png(result["path"])
	
	call_deferred("_serialize_screenshot_done")
	
	return {"error":error, "path":result["path"]}
	
func _serialize_screenshot_done() -> void:
	var result: Dictionary = image_thread.wait_to_finish()
	var err: int = result["error"]
	var path: String = result["path"]
	print("Screenshot serialised at '%s' with error code: %s" % [path, str(err)])
	
	pending = false
	if err == OK:
		emit_signal("screenshot_saved", path)
	else:
		emit_signal("screenshot_failed", path, err)

func _screenshot_captured(p_info: Dictionary, p_image: Image) -> void:
	if(p_image != null):
		var directory_ready: bool = false
		var screenshot_directory: String = p_info["screenshot_directory"]
		
		var dir = Directory.new()
		if(dir.open("user://") == OK):
			if(dir.dir_exists(screenshot_directory)):
				directory_ready = true
			else:
				if dir.make_dir(screenshot_directory) == OK:
					directory_ready = true
		
		if directory_ready:
			if(image_thread.start(self, "_unsafe_serialize_screenshot", 
			{
				"image":p_image,
				"info":p_info
			}) != OK):
				printerr("Could not create start processing thread!")

func capture_screenshot(p_info: Dictionary) -> void:
	if !pending:
		pending = true
		print("Capturing screenshot (%s)..." % p_info["screenshot_type"])
		
		var callback = FuncRef.new()
		callback.set_instance(self)
		callback.set_function("_screenshot_captured")
		
		emit_signal("screenshot_requested", p_info, callback)

func _input(p_event: InputEvent) -> void:
	if p_event.is_action_pressed("screenshot"):
		var screenshot_path_callback: FuncRef = FuncRef.new()
		screenshot_path_callback.set_instance(self)
		screenshot_path_callback.set_function("_date_and_time_screenshot")
		
		capture_screenshot(
			{
				"screenshot_path_callback":screenshot_path_callback,
				"screenshot_type":"screenshot",
				"screenshot_directory":"user://screenshots"
			})
