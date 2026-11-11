extends AudioStreamPlayer

func _ready() -> void:
	if stream is AudioStreamMP3:
		stream.loop = true
	play()
