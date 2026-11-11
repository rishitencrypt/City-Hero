extends Node

const REWARD: int = 10

var reputation: int = 0
var task_complete: bool = false


func report_scam() -> void:
	if task_complete:
		return

	task_complete = true
	reputation = REWARD
