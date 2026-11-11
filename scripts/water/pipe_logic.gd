class_name PipeLogic
extends RefCounted
## Pure helpers for pipe openings. Openings are bit flags: N=1, E=2, S=4, W=8.
## Rotation is clockwise: N -> E -> S -> W -> N.

const N: int = 1
const E: int = 2
const S: int = 4
const W: int = 8
const DIRS: Array[int] = [1, 2, 4, 8]

enum PipeType { EMPTY, STRAIGHT, ELBOW, SOURCE, DEST }


static func opposite(d: int) -> int:
	return ((d << 2) & 15) | (d >> 2)


static func dir_vector(d: int) -> Vector2i:
	if d == N:
		return Vector2i(0, -1)
	if d == E:
		return Vector2i(1, 0)
	if d == S:
		return Vector2i(0, 1)
	return Vector2i(-1, 0)


static func dir_from_delta(v: Vector2i) -> int:
	if v == Vector2i(0, -1):
		return N
	if v == Vector2i(1, 0):
		return E
	if v == Vector2i(0, 1):
		return S
	if v == Vector2i(-1, 0):
		return W
	return 0


static func rotate_mask(mask: int, steps: int) -> int:
	var m: int = mask
	for _i in posmod(steps, 4):
		m = ((m << 1) & 15) | ((m >> 3) & 1)
	return m


## Openings of a piece at rotation 0.
static func base_mask(type: int) -> int:
	if type == PipeType.STRAIGHT:
		return N | S
	if type == PipeType.ELBOW:
		return N | E
	if type == PipeType.SOURCE:
		return E
	if type == PipeType.DEST:
		return W
	return 0


static func mask_of(type: int, rot: int) -> int:
	return rotate_mask(base_mask(type), rot)


static func is_fixed(type: int) -> bool:
	return type == PipeType.SOURCE or type == PipeType.DEST
