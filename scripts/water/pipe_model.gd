class_name PipeModel
extends RefCounted
## Grid state + generation + flow validation. No UI code in here.
## Layout: SOURCE is on the left edge (opens East), DEST on the right edge (opens West).
## generate() is DETERMINISTIC: it uses a local seeded RandomNumberGenerator, so the same
## seed always yields the same winding route, decoys and starting rotations, and the
## global random state is never touched. A route is carved first, so a solution always
## exists (every route piece can reach its required opening by 90-degree clockwise turns).

const DEFAULT_SEED: int = 20261014
const MIN_PATH: int = 8
const MAX_PATH: int = 13
const MIN_TURNS: int = 4   # winding: at least this many elbows on the route

var cols: int
var rows: int
var types: PackedInt32Array = PackedInt32Array()
var rots: PackedInt32Array = PackedInt32Array()
var initial_rots: PackedInt32Array = PackedInt32Array()
var solution_rots: PackedInt32Array = PackedInt32Array()   # -1 = not on solution path
var required_masks: PackedInt32Array = PackedInt32Array()
var source_index: int = -1
var dest_index: int = -1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _init(p_cols: int = 6, p_rows: int = 5) -> void:
	cols = maxi(p_cols, 4)
	rows = maxi(p_rows, 3)


func idx(x: int, y: int) -> int:
	return y * cols + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < cols and y < rows


func get_mask(i: int) -> int:
	return PipeLogic.mask_of(types[i], rots[i])


func generate(p_seed: int = DEFAULT_SEED) -> void:
	_rng.seed = p_seed
	var total: int = cols * rows
	types.resize(total)
	rots.resize(total)
	solution_rots.resize(total)
	required_masks.resize(total)

	# Decoy pieces everywhere first.
	for i in total:
		if _rng.randf() < 0.5:
			types[i] = PipeLogic.PipeType.STRAIGHT
		else:
			types[i] = PipeLogic.PipeType.ELBOW
		rots[i] = _rng.randi() % 4
		solution_rots[i] = -1
		required_masks[i] = 0

	var path: Array[Vector2i] = _find_path()

	source_index = idx(0, path[0].y)
	types[source_index] = PipeLogic.PipeType.SOURCE
	rots[source_index] = 0
	dest_index = idx(cols - 1, path[path.size() - 1].y)
	types[dest_index] = PipeLogic.PipeType.DEST
	rots[dest_index] = 0

	var path_indices: Array[int] = []
	for i in path.size():
		var cell: Vector2i = path[i]
		var prev_cell: Vector2i = Vector2i(0, cell.y)
		if i > 0:
			prev_cell = path[i - 1]
		var next_cell: Vector2i = Vector2i(cols - 1, cell.y)
		if i < path.size() - 1:
			next_cell = path[i + 1]
		var need: int = PipeLogic.dir_from_delta(prev_cell - cell) | PipeLogic.dir_from_delta(next_cell - cell)
		var t: int = PipeLogic.PipeType.ELBOW
		if need == (PipeLogic.N | PipeLogic.S) or need == (PipeLogic.E | PipeLogic.W):
			t = PipeLogic.PipeType.STRAIGHT
		var pi: int = idx(cell.x, cell.y)
		types[pi] = t
		required_masks[pi] = need
		for r in 4:
			if PipeLogic.mask_of(t, r) == need:
				solution_rots[pi] = r
				break
		path_indices.append(pi)

	# Scramble route pieces (seeded) until the puzzle is clearly unsolved.
	for _attempt in 100:
		for pi in path_indices:
			rots[pi] = _rng.randi() % 4
		if _misplaced_count() >= 3 and not bool(evaluate()["solved"]):
			break
	if bool(evaluate()["solved"]):
		var first: int = path_indices[0]
		rots[first] = (rots[first] + 1) % 4
	initial_rots = rots.duplicate()


func _misplaced_count() -> int:
	var n: int = 0
	for i in types.size():
		if required_masks[i] != 0 and get_mask(i) != required_masks[i]:
			n += 1
	return n


func _find_path() -> Array[Vector2i]:
	var best: Array[Vector2i] = []
	for _i in 200:
		var start: Vector2i = Vector2i(1, _rng.randi_range(0, rows - 1))
		var goal: Vector2i = Vector2i(cols - 2, _rng.randi_range(0, rows - 1))
		var visited: Dictionary = {}
		var path: Array[Vector2i] = []
		if _dfs(start, goal, visited, path):
			if best.is_empty():
				best = path
			if path.size() >= MIN_PATH and path.size() <= MAX_PATH and _count_turns(path) >= MIN_TURNS:
				return path
	return best


## Number of direction changes along source -> route -> dest (= elbows on the route).
func _count_turns(path: Array[Vector2i]) -> int:
	var pts: Array[Vector2i] = [Vector2i(0, path[0].y)]
	pts.append_array(path)
	pts.append(Vector2i(cols - 1, path[path.size() - 1].y))
	var turns: int = 0
	for i in range(1, pts.size() - 1):
		if pts[i] - pts[i - 1] != pts[i + 1] - pts[i]:
			turns += 1
	return turns


func _shuffled_dirs() -> Array[int]:
	var order: Array[int] = [PipeLogic.N, PipeLogic.E, PipeLogic.S, PipeLogic.W]
	for i in range(order.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	return order


func _dfs(cur: Vector2i, goal: Vector2i, visited: Dictionary, path: Array[Vector2i]) -> bool:
	visited[cur] = true
	path.append(cur)
	if cur == goal:
		return true
	for d in _shuffled_dirs():
		var nxt: Vector2i = cur + PipeLogic.dir_vector(d)
		if nxt.x < 1 or nxt.x > cols - 2 or nxt.y < 0 or nxt.y >= rows:
			continue
		if visited.has(nxt):
			continue
		if _dfs(nxt, goal, visited, path):
			return true
	path.pop_back()
	visited.erase(cur)
	return false


## Rotates one piece 90 degrees clockwise. Returns false for fixed pieces.
func rotate_cell(i: int) -> bool:
	if i < 0 or i >= types.size() or PipeLogic.is_fixed(types[i]):
		return false
	rots[i] = (rots[i] + 1) % 4
	return true


func reset() -> void:
	rots = initial_rots.duplicate()


## Debug/test helper: put every route piece in its solved rotation.
func apply_solution() -> void:
	for i in types.size():
		if solution_rots[i] >= 0:
			rots[i] = solution_rots[i]


## Flood-fills from the source through MATCHING openings only (both neighbours must
## open toward each other). Returns {"solved": bool, "connected": Dictionary[index->true]}.
func evaluate() -> Dictionary:
	var connected: Dictionary = {}
	var queue: Array[int] = [source_index]
	connected[source_index] = true
	while not queue.is_empty():
		var i: int = queue.pop_front()
		var x: int = i % cols
		var y: int = floori(float(i) / float(cols))
		var m: int = get_mask(i)
		for d in PipeLogic.DIRS:
			if (m & d) == 0:
				continue
			var n: Vector2i = Vector2i(x, y) + PipeLogic.dir_vector(d)
			if not in_bounds(n.x, n.y):
				continue
			var ni: int = idx(n.x, n.y)
			if connected.has(ni):
				continue
			if (get_mask(ni) & PipeLogic.opposite(d)) != 0:
				connected[ni] = true
				queue.append(ni)
	return {"solved": connected.has(dest_index), "connected": connected}
