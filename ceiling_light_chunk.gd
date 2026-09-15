extends MeshInstance3D

@onready var light: OmniLight3D = $OmniLight3D

const DEATH_CHANCE := 0.12

var _base_energy := 0.0
var _timer := Timer.new()
var _flicker_step := 0
var _flicker_steps := 0
var _dying := false
var _region_dark := false
var _region_id: Vector2i

func _ready() -> void:
	_base_energy = light.light_energy
	_apply_visual(true)

	_timer.one_shot = true
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	_start_idle()

	_region_id = LightingDirector.register(self)

func _exit_tree() -> void:
	LightingDirector.unregister(self, _region_id)

func _start_idle() -> void:
	_timer.start(randf_range(5.0, 15.0))

func _on_timer_timeout() -> void:
	if _dying:
		_dying = false
		_set_lit(true)
		_start_idle()
		return

	if _flicker_steps == 0:
		_flicker_steps = randi_range(4, 10)
		_flicker_step = 0

	_flicker_step += 1
	_set_lit(_flicker_step % 2 == 0)

	if _flicker_step < _flicker_steps:
		_timer.start(randf_range(0.03, 0.15))
		return

	_flicker_steps = 0
	if randf() < DEATH_CHANCE:
		_dying = true
		_set_lit(false)
		_timer.start(randf_range(4.0, 10.0))
	else:
		_set_lit(true)
		_start_idle()

func region_flicker_burst(delay: float = 0.0) -> void:
	if _region_dark:
		return
	_dying = false
	_flicker_steps = 0
	_timer.start(max(delay, 0.01))

func region_set_dark(dark: bool) -> void:
	_region_dark = dark
	if dark:
		_apply_visual(false)
	else:
		_apply_visual(true)
		_dying = false
		_flicker_steps = 0
		_start_idle()

func _set_lit(enabled: bool) -> void:
	if _region_dark:
		return
	_apply_visual(enabled)

func _apply_visual(enabled: bool) -> void:
	light.light_energy = _base_energy if enabled else 0.0

	var material := get_surface_override_material(0)
	if material == null:
		var base := get_active_material(0)
		if base == null:
			return
		material = base.duplicate()
		set_surface_override_material(0, material)

	material.emission_enabled = enabled
