extends CharacterBody3D

const SPEED = 3.0
const SPRINT_SPEED = 6.0
const SENSITIVITY = 0.002
const GRAVITY = 9.81

const CAMERA_SMOOTHNESS = 15.0  # higher = faster
const FLASHLIGHT_SMOOTHNESS = 5.0 # lower = slower

const BOB_FREQUENCY = 6
const BOB_AMPLITUDE = 0.045

const BREATH_VOLUME_DB = 10.0
const BREATH_SILENT_DB = -80.0
const BREATH_RAMP_TIME = 0.2
const BREATH_FADE_TIME = 3.0

@export var footstep_sounds: Array[AudioStream] = []

var bob_time := 0.0
var default_cam_pos := Vector3.ZERO
var _step_phase := 0
var _placeholder_beep: AudioStreamWAV
var _sprinting := false
var _breath_tween: Tween
var _sprint_elapsed := 0.0

@onready var head = $Head
@onready var camera = $Head/Camera3D  # Assuming Camera is inside Head
@onready var hand = $Hand              # Hand is a child of CharacterBody3D
@onready var footsteps: AudioStreamPlayer3D = $Footsteps
@onready var exertion_breath: AudioStreamPlayer = $ExertionBreath

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	default_cam_pos = camera.position
	_placeholder_beep = _generate_placeholder_beep()

	if exertion_breath.stream is AudioStreamWAV:
		var wav := exertion_breath.stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_begin = 0
		wav.loop_end = int(wav.get_length() * wav.mix_rate)

var target_rot_y = 0.0
var target_rot_x = 0.0

func _input(event):
	if event is InputEventMouseMotion:
		target_rot_y -= event.relative.x * SENSITIVITY
		target_rot_x -= event.relative.y * SENSITIVITY
		target_rot_x = clamp(target_rot_x, -deg_to_rad(89.0), deg_to_rad(89.0))

func _physics_process(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var input_dir = Vector3.ZERO
	if Input.is_action_pressed("ui_up"): input_dir.z -= 1
	if Input.is_action_pressed("ui_down"): input_dir.z += 1
	if Input.is_action_pressed("ui_left"): input_dir.x -= 1
	if Input.is_action_pressed("ui_right"): input_dir.x += 1
	input_dir = input_dir.normalized()

	var head_basis = head.global_transform.basis
	var direction = (head_basis * input_dir)
	direction.y = 0
	direction = direction.normalized()

	var sprinting := is_on_floor() and input_dir != Vector3.ZERO and Input.is_action_pressed("ui_shift")
	var speed := SPRINT_SPEED if sprinting else SPEED

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed

	move_and_slide()

	_update_breathing(sprinting, delta)

	# --- Head Bobbing + Footstep Logic ---
	if is_on_floor() and (velocity.x != 0 or velocity.z != 0):
		if not sprinting:
			bob_time += delta * BOB_FREQUENCY
		else:
			bob_time += delta * BOB_FREQUENCY * 1.75
		
		camera.position.y = default_cam_pos.y + sin(bob_time) * BOB_AMPLITUDE
		camera.position.x = default_cam_pos.x + cos(bob_time / 2) * (BOB_AMPLITUDE * 0.5)

		# A footstep lands every half bob cycle (alternating feet)
		var phase := int(floor(bob_time / PI))
		if phase != _step_phase:
			_step_phase = phase
			_play_footstep()
	else:
		bob_time = 0.0
		_step_phase = 0
		camera.position.y = lerp(camera.position.y, default_cam_pos.y, CAMERA_SMOOTHNESS * delta)
		camera.position.x = lerp(camera.position.x, default_cam_pos.x, CAMERA_SMOOTHNESS * delta)
	# --------------------------------------

	head.rotation.y = lerp_angle(head.rotation.y, target_rot_y, CAMERA_SMOOTHNESS * delta)
	camera.rotation.x = lerp_angle(camera.rotation.x, target_rot_x, CAMERA_SMOOTHNESS * delta)

	hand.rotation.y = lerp_angle(hand.rotation.y, head.rotation.y, FLASHLIGHT_SMOOTHNESS * delta)
	hand.rotation.x = lerp_angle(hand.rotation.x, camera.rotation.x, FLASHLIGHT_SMOOTHNESS * delta)

func _update_breathing(sprinting: bool, delta: float) -> void:
	if sprinting:
		_sprint_elapsed += delta
		if not _sprinting:
			_start_exertion()
	elif _sprinting:
		_start_recovery_fade()

	_sprinting = sprinting

func _start_exertion() -> void:
	if _breath_tween and _breath_tween.is_valid():
		_breath_tween.kill()

	if not exertion_breath.playing:
		exertion_breath.play()

	_breath_tween = create_tween()
	_breath_tween.tween_property(exertion_breath, "volume_db", BREATH_VOLUME_DB, BREATH_RAMP_TIME)

func _start_recovery_fade() -> void:
	if _breath_tween and _breath_tween.is_valid():
		_breath_tween.kill()

	var hold_time := _sprint_elapsed
	_sprint_elapsed = 0.0

	_breath_tween = create_tween()
	_breath_tween.tween_interval(hold_time)
	_breath_tween.tween_property(exertion_breath, "volume_db", BREATH_SILENT_DB, BREATH_FADE_TIME)
	_breath_tween.tween_callback(exertion_breath.stop)

func _play_footstep() -> void:
	if footstep_sounds.is_empty():
		footsteps.stream = _placeholder_beep
	else:
		footsteps.stream = footstep_sounds[randi() % footstep_sounds.size()]

	footsteps.pitch_scale = randf_range(0.92, 1.08)
	footsteps.play()

func _generate_placeholder_beep() -> AudioStreamWAV:
	var mix_rate := 22050
	var freq := 600.0
	var duration := 0.08
	var sample_count := int(mix_rate * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var t := float(i) / sample_count
		var envelope: float = sin(PI * t)  # fade in/out so the beep doesn't click
		var sample: float = sin(TAU * freq * (float(i) / mix_rate)) * envelope
		data.encode_s16(i * 2, int(sample * 32767.0))

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = mix_rate
	stream.stereo = false
	stream.data = data
	return stream
