extends SceneTree
## Run (Mac example):
## /Applications/Godot.app/Contents/MacOS/Godot --headless --path /path/to/project -s res://tests/pipe_selftest.gd
## Open the project in the editor once first so the global class names are registered.

func _init() -> void:
	var failures: int = 0

	# Rotation math (clockwise).
	if PipeLogic.rotate_mask(PipeLogic.N, 1) != PipeLogic.E:
		failures += 1
		print("FAIL: N rotated once should be E")
	if PipeLogic.rotate_mask(PipeLogic.W, 1) != PipeLogic.N:
		failures += 1
		print("FAIL: W rotated once should be N")
	if PipeLogic.rotate_mask(PipeLogic.N | PipeLogic.E, 4) != (PipeLogic.N | PipeLogic.E):
		failures += 1
		print("FAIL: four rotations should return to start")
	if PipeLogic.opposite(PipeLogic.N) != PipeLogic.S or PipeLogic.opposite(PipeLogic.E) != PipeLogic.W:
		failures += 1
		print("FAIL: opposite()")

	# Generator + validator.
	for n in 1000:
		var m: PipeModel = PipeModel.new(6, 5)
		m.generate()
		if bool(m.evaluate()["solved"]):
			failures += 1
			print("FAIL: puzzle %d starts solved" % n)
			continue
		m.apply_solution()
		if not bool(m.evaluate()["solved"]):
			failures += 1
			print("FAIL: puzzle %d solution not accepted" % n)
			continue
		# Break the route: rotate one elbow on the path; must no longer be solved.
		for i in m.types.size():
			if m.solution_rots[i] >= 0 and m.types[i] == PipeLogic.PipeType.ELBOW:
				m.rotate_cell(i)
				if bool(m.evaluate()["solved"]):
					failures += 1
					print("FAIL: puzzle %d still solved after breaking an elbow" % n)
				break

	print("Pipe self-test finished: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)
