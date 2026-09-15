extends Node3D

@onready var player = $Player

var WallScene = preload("res://wall.tscn")
var FloorChunk = preload("res://Floor_Chunk.tscn")
var CeilingChunk = preload("res://Ceiling_Chunk.tscn")
var CeilingLightChunk = preload("res://Ceiling_Light_Chunk.tscn")

const CHUNK_SIZE = 3
const RENDER_DISTANCE = 15
# Godot's Compatibility renderer (the only one available on the Web target)
# silently stops drawing ALL 3D geometry once the scene holds roughly 1000+
# MeshInstance3D nodes - no error, still 180fps, just an empty frame.
# Measured in Chrome/WebGL2: 821 meshes draw fine, 1035 draw nothing at all.
# RENDER_DISTANCE 15 builds ~2357 meshes, so stream a smaller radius on Web.
const WEB_RENDER_DISTANCE = 8
const LIGHT_SPACING = 2

const DARK_ZONE_SEED = 1337
const DARK_ZONE_FREQUENCY = 0.06
const DARK_ZONE_THRESHOLD = 0.35

const WALL_WIDTH = 5.0
const WALL_HEIGHT = 5.0
const WALL_THICKNESS = 0.2
const CORNER_SIZE = WALL_THICKNESS / 2.0

const MAZE_SIZE = 64
const MAZE_FILL_PERCENTAGE = 0.8
const NUM_MAZE_OVERLAYS = 50
const STOP_COLLISION_PROBABILITY = 0.5

const NUM_ROOMS = 8
const ROOM_WIDTH_RANGE = Vector2i(2, 8)
const ROOM_HEIGHT_RANGE = Vector2i(2, 8)
const NUM_PILLAR_ROOMS = 3
const PILLAR_SPACING_RANGE = Vector2i(2, 4)

var maze_grid: Array = []
var grid_offset: Vector2i

var spawned_chunks: Dictionary = {}

var _dark_zone_noise := FastNoiseLite.new()
var render_distance := RENDER_DISTANCE

func _ready() -> void:
	if OS.has_feature("web"):
		render_distance = WEB_RENDER_DISTANCE

	generate_maze_grid()
	grid_offset = Vector2i(MAZE_SIZE / 2, MAZE_SIZE / 2)

	_dark_zone_noise.seed = DARK_ZONE_SEED
	_dark_zone_noise.frequency = DARK_ZONE_FREQUENCY

func _process(_delta: float) -> void:
	update_chunks()


# ============================================================================
# MAZE GENERATION
# ============================================================================

func generate_maze_grid():
	maze_grid = []
	for y in range(MAZE_SIZE):
		var row: Array = []
		for x in range(MAZE_SIZE):
			row.append(false)
		maze_grid.append(row)

	for i in range(NUM_MAZE_OVERLAYS):
		_overlay_maze_pass()

	_generate_rooms()
	_generate_pillar_rooms()

	var center = int(MAZE_SIZE / 2)
	for x in range(center - 2, center + 3):
		for y in range(center - 2, center + 3):
			maze_grid[y][x] = true

func _overlay_maze_pass():
	var visited_cells: Dictionary = {}

	var start_x = randi() % MAZE_SIZE
	var start_y = randi() % MAZE_SIZE

	visited_cells[Vector2i(start_x, start_y)] = true
	maze_grid[start_y][start_x] = true

	var frontier: Array[Vector2i] = [Vector2i(start_x, start_y)]
	var total_cells = MAZE_SIZE * MAZE_SIZE

	while float(visited_cells.size()) / float(total_cells) < MAZE_FILL_PERCENTAGE:
		if frontier.is_empty():
			break

		var idx = randi() % frontier.size()
		var current = frontier[idx]
		frontier.remove_at(idx)

		visited_cells[current] = true
		maze_grid[current.y][current.x] = true

		var neighbors: Array[Vector2i] = []

		if current.x > 1 and not visited_cells.has(Vector2i(current.x - 2, current.y)):
			neighbors.append(Vector2i(current.x - 2, current.y))
		if current.x < MAZE_SIZE - 2 and not visited_cells.has(Vector2i(current.x + 2, current.y)):
			neighbors.append(Vector2i(current.x + 2, current.y))
		if current.y > 1 and not visited_cells.has(Vector2i(current.x, current.y - 2)):
			neighbors.append(Vector2i(current.x, current.y - 2))
		if current.y < MAZE_SIZE - 2 and not visited_cells.has(Vector2i(current.x, current.y + 2)):
			neighbors.append(Vector2i(current.x, current.y + 2))

		if not neighbors.is_empty():
			var next = neighbors[randi() % neighbors.size()]
			var mid_x = int((current.x + next.x) / 2)
			var mid_y = int((current.y + next.y) / 2)

			if randf() > STOP_COLLISION_PROBABILITY or not maze_grid[mid_y][mid_x]:
				frontier.append(next)
				maze_grid[mid_y][mid_x] = true

func _generate_rooms():
	for i in range(NUM_ROOMS):
		var room_w = randi_range(ROOM_WIDTH_RANGE.x, ROOM_WIDTH_RANGE.y)
		var room_h = randi_range(ROOM_HEIGHT_RANGE.x, ROOM_HEIGHT_RANGE.y)

		var x = randi() % (MAZE_SIZE - room_w)
		var y = randi() % (MAZE_SIZE - room_h)

		for row in range(y, y + room_h):
			for col in range(x, x + room_w):
				maze_grid[row][col] = true

func _generate_pillar_rooms():
	for i in range(NUM_PILLAR_ROOMS):
		var room_w = randi_range(ROOM_WIDTH_RANGE.x, ROOM_WIDTH_RANGE.y)
		var room_h = randi_range(ROOM_HEIGHT_RANGE.x, ROOM_HEIGHT_RANGE.y)

		var x = randi() % (MAZE_SIZE - room_w)
		var y = randi() % (MAZE_SIZE - room_h)

		for row in range(y, y + room_h):
			for col in range(x, x + room_w):
				maze_grid[row][col] = true

		var pillar_spacing = randi_range(PILLAR_SPACING_RANGE.x, PILLAR_SPACING_RANGE.y)

		for row in range(y, y + room_h, pillar_spacing):
			for col in range(x, x + room_w, pillar_spacing):
				maze_grid[row][col] = false

# ============================================================================
# CHUNKS
# ============================================================================

func update_chunks():
	var p = player.global_position
	var cx = int(p.x / CHUNK_SIZE)
	var cz = int(p.z / CHUNK_SIZE)

	var needed = {}

	for x in range(cx - render_distance, cx + render_distance):
		for z in range(cz - render_distance, cz + render_distance):
			var key = str(x) + "," + str(z)
			needed[key] = true

			if not spawned_chunks.has(key):
				spawn_chunk(x, z)

	for key in spawned_chunks.keys():
		if not needed.has(key):
			despawn_chunk(key)

func spawn_chunk(x: int, z: int):
	var key = str(x) + "," + str(z)

	var chunk_data = {
		"floor": null,
		"ceiling": null,
		"walls": []
	}

	var floor_chunk = FloorChunk.instantiate()
	floor_chunk.position = Vector3(x * CHUNK_SIZE, 0, z * CHUNK_SIZE)
	add_child(floor_chunk)
	chunk_data["floor"] = floor_chunk

	var wants_light = x % LIGHT_SPACING == 0 and z % LIGHT_SPACING == 0 and not _is_dark_zone(x, z)
	var ceiling_chunk = CeilingLightChunk.instantiate() if wants_light else CeilingChunk.instantiate()
	ceiling_chunk.position = Vector3(x * CHUNK_SIZE, 5.1, z * CHUNK_SIZE)
	add_child(ceiling_chunk)
	chunk_data["ceiling"] = ceiling_chunk

	var grid_x = x + grid_offset.x
	var grid_z = z + grid_offset.y

	if grid_x >= 0 and grid_x < MAZE_SIZE and grid_z >= 0 and grid_z < MAZE_SIZE:
		if not maze_grid[grid_z][grid_x]:
			var north_open = _is_open(grid_x, grid_z + 1)
			var south_open = _is_open(grid_x, grid_z - 1)
			var east_open = _is_open(grid_x + 1, grid_z)
			var west_open = _is_open(grid_x - 1, grid_z)

			if north_open:
				_spawn_wall(chunk_data, x, z, 0, CHUNK_SIZE / 2.0, 0)
			if south_open:
				_spawn_wall(chunk_data, x, z, 0, -CHUNK_SIZE / 2.0, 0)
			if east_open:
				_spawn_wall(chunk_data, x, z, CHUNK_SIZE / 2.0, 0, PI / 2.0)
			if west_open:
				_spawn_wall(chunk_data, x, z, -CHUNK_SIZE / 2.0, 0, PI / 2.0)

			if north_open and east_open:
				_spawn_corner(chunk_data, x, z, 1.0, 1.0)
			if north_open and west_open:
				_spawn_corner(chunk_data, x, z, -1.0, 1.0)
			if south_open and east_open:
				_spawn_corner(chunk_data, x, z, 1.0, -1.0)
			if south_open and west_open:
				_spawn_corner(chunk_data, x, z, -1.0, -1.0)

	spawned_chunks[key] = chunk_data

func _is_dark_zone(x: int, z: int) -> bool:
	return _dark_zone_noise.get_noise_2d(x, z) > DARK_ZONE_THRESHOLD

func _is_open(grid_x: int, grid_z: int) -> bool:
	if grid_x < 0 or grid_x >= MAZE_SIZE or grid_z < 0 or grid_z >= MAZE_SIZE:
		return true
	return maze_grid[grid_z][grid_x]

func _spawn_wall(chunk_data: Dictionary, cx: int, cz: int, offset_x: float, offset_z: float, rot_y: float):
	var wall = WallScene.instantiate()

	wall.position = Vector3(
		cx * CHUNK_SIZE + offset_x,
		0,
		cz * CHUNK_SIZE + offset_z
	)

	wall.rotation.y = rot_y
	wall.scale = Vector3(CHUNK_SIZE / WALL_WIDTH, 1.0, 1.0)

	add_child(wall)
	chunk_data["walls"].append(wall)

func _spawn_corner(chunk_data: Dictionary, cx: int, cz: int, sign_x: float, sign_z: float):
	var corner = WallScene.instantiate()

	corner.position = Vector3(
		cx * CHUNK_SIZE + sign_x * (CHUNK_SIZE / 2.0 + CORNER_SIZE / 2.0),
		0,
		cz * CHUNK_SIZE + sign_z * (CHUNK_SIZE / 2.0 + CORNER_SIZE / 2.0)
	)

	corner.scale = Vector3(CORNER_SIZE / WALL_WIDTH, 1.0, CORNER_SIZE / WALL_THICKNESS)

	add_child(corner)
	chunk_data["walls"].append(corner)

func despawn_chunk(key: String):
	var chunk = spawned_chunks[key]

	chunk["floor"].queue_free()
	chunk["ceiling"].queue_free()

	for wall in chunk["walls"]:
		wall.queue_free()

	spawned_chunks.erase(key)
