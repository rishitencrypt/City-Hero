extends AudioStreamPlayer

func play_sound(sound: AudioStream) -> void:
	if sound == null:
		return
	stream = sound
	play()
