extends Node

const REGION_SIZE := 6.0
const EVENT_INTERVAL_MIN := 6.0
const EVENT_INTERVAL_MAX := 18.0
const BLACKOUT_CHANCE := 0.18
const BLACKOUT_MIN := 5.0
const BLACKOUT_MAX := 15.0
const BURST_STAGGER := 0.4

class Region:
	var fixtures: Array = []
	var timer: Timer
	var blacked_out := false

var _regions: Dictionary = {}

func register(fixture: Node3D) -> Vector2i:
	var region_id := _region_id_for(fixture.global_position)
	var region: Region = _regions.get(region_id)

	if region == null:
		region = Region.new()
		region.timer = Timer.new()
		region.timer.one_shot = true
		add_child(region.timer)
		region.timer.timeout.connect(_on_region_timeout.bind(region_id))
		region.timer.start(randf_range(EVENT_INTERVAL_MIN, EVENT_INTERVAL_MAX))
		_regions[region_id] = region

	region.fixtures.append(fixture)
	if region.blacked_out:
		fixture.region_set_dark(true)

	return region_id

func unregister(fixture: Node3D, region_id: Vector2i) -> void:
	var region: Region = _regions.get(region_id)
	if region == null:
		return

	region.fixtures.erase(fixture)
	if region.fixtures.is_empty():
		region.timer.queue_free()
		_regions.erase(region_id)

func _region_id_for(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / REGION_SIZE), floori(pos.z / REGION_SIZE))

func _on_region_timeout(region_id: Vector2i) -> void:
	var region: Region = _regions.get(region_id)
	if region == null:
		return

	if region.blacked_out:
		region.blacked_out = false
		for fixture in region.fixtures:
			if is_instance_valid(fixture):
				fixture.region_set_dark(false)
		region.timer.start(randf_range(EVENT_INTERVAL_MIN, EVENT_INTERVAL_MAX))
		return

	if randf() < BLACKOUT_CHANCE:
		region.blacked_out = true
		for fixture in region.fixtures:
			if is_instance_valid(fixture):
				fixture.region_set_dark(true)
		region.timer.start(randf_range(BLACKOUT_MIN, BLACKOUT_MAX))
	else:
		for fixture in region.fixtures:
			if is_instance_valid(fixture):
				fixture.region_flicker_burst(randf_range(0.0, BURST_STAGGER))
		region.timer.start(randf_range(EVENT_INTERVAL_MIN, EVENT_INTERVAL_MAX))
