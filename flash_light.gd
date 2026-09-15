extends SpotLight3D

@export var flashlight_sounds: Array[AudioStream] = [
	preload("res://sounds/Flashlight/click_1.mp3"),
	preload("res://sounds/Flashlight/click_2.mp3")
]

@onready var flashlight: AudioStreamPlayer3D = $Flashlight

var last_sound := -1

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		visible = not visible

		if flashlight_sounds.size() > 0:
			var index = randi() % flashlight_sounds.size()

			while flashlight_sounds.size() > 1 and index == last_sound:
				index = randi() % flashlight_sounds.size()

			last_sound = index
			flashlight.stream = flashlight_sounds[index]
			flashlight.play()
