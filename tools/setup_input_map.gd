extends SceneTree

## 用 Godot 自己的序列化器生成 project.godot 的 [input] 段。
## Generate the [input] section of project.godot using Godot's own serializer.
##
## 手写 Object(InputEventKey,...) 那一长串极易写错，所以交给引擎来写。
## Hand-writing the Object(InputEventKey,...) blob is error-prone; let the engine emit it.
##
## Run: tools/g.sh setup-input

const ACTIONS: Dictionary = {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"move_up": [KEY_W, KEY_UP],
	"move_down": [KEY_S, KEY_DOWN],
}


func _initialize() -> void:
	for action: String in ACTIONS:
		# 必须是无类型 Array：Array[InputEventKey] 会被序列化成
		# `Array[InputEventKey]([...])`，而编辑器写的是裸 `[...]`。
		# Must be an untyped Array: a typed one serializes as
		# `Array[InputEventKey]([...])` whereas the editor emits a bare `[...]`.
		var events: Array = []
		for keycode: Key in ACTIONS[action]:
			var event := InputEventKey.new()
			# physical_keycode 而非 keycode：与键盘布局无关（AZERTY 上 WASD 仍在原位）。
			# physical_keycode not keycode: layout-independent (WASD stays put on AZERTY).
			event.physical_keycode = keycode
			# 显式 -1 = 匹配任意设备。InputEventKey.new() 在 4.7 上默认给的是 16，
			# 那不是标准工程里的值，别留着。
			# Explicit -1 = match any device. InputEventKey.new() defaults to 16 on 4.7,
			# which is not what stock projects contain.
			event.device = -1
			events.append(event)
		ProjectSettings.set_setting("input/" + action, {"deadzone": 0.2, "events": events})
		print("  + %s -> %s" % [action, ACTIONS[action]])

	var err: Error = ProjectSettings.save()
	if err != OK:
		printerr("ProjectSettings.save() failed: %s" % error_string(err))
		quit(1)
		return
	print("project.godot saved with %d input actions" % ACTIONS.size())
	quit(0)
