extends Node
## 効果音を実行時に合成する軽量シンセ。
## 外部音声アセットを使わず、短いトーン/ノイズを合成してSEとして再生する。
## Autoload("AudioFx")として登録されている。

const MIX_RATE := 22050
const POOL_SIZE := 6

var streams: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var next_player := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	for i in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		add_child(player)
		players.append(player)
	# SEの合成はここでまとめて行わず、初回再生時に1件ずつ遅延生成してキャッシュする
	# (起動時に全SEを合成すると、その分だけ読み込みが体感で遅くなるため)。


func play(id: String, volume_db: float = 0.0) -> void:
	var stream := _get_stream(id)
	if stream == null:
		return
	var player := players[next_player]
	next_player = (next_player + 1) % players.size()
	player.stream = stream
	player.volume_db = volume_db
	player.play()


func _get_stream(id: String) -> AudioStreamWAV:
	if streams.has(id):
		return streams[id]
	var stream := _build_stream(id)
	if stream != null:
		streams[id] = stream
	return stream


func _build_stream(id: String) -> AudioStreamWAV:
	match id:
		"decide":
			return _tone(880.0, 0.06, "square", 0.45)
		"dice_tick":
			return _tone(1400.0, 0.025, "square", 0.3)
		"dice_land":
			return _sequence([392.0, 523.25], 0.09, "square", 0.5)
		"hit":
			return _tone(180.0, 0.05, "square", 0.5)
		"damage":
			return _noise_burst(0.12, 0.5)
		"heal":
			return _sequence([523.25, 659.25, 783.99], 0.07, "sine", 0.4)
		"gold":
			return _sequence([1046.5, 1318.5], 0.06, "square", 0.35)
		"danger":
			return _sequence([246.94, 220.0], 0.1, "square", 0.42)
		"victory":
			return _sequence([523.25, 659.25, 783.99, 1046.5], 0.11, "sine", 0.45)
		"defeat":
			return _sequence([392.0, 329.63, 261.63], 0.16, "sine", 0.4)
		_:
			return null


func _make_wav(sample_count: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	return wav


func _tone(freq: float, duration: float, wave: String, amplitude: float) -> AudioStreamWAV:
	return _sequence([freq], duration, wave, amplitude)


func _sequence(freqs: Array, note_duration: float, wave: String, amplitude: float) -> AudioStreamWAV:
	var samples_per_note := int(MIX_RATE * note_duration)
	var total_samples := samples_per_note * freqs.size()
	var data := PackedByteArray()
	data.resize(total_samples * 2)

	for note_index in range(freqs.size()):
		var freq: float = freqs[note_index]
		for i in range(samples_per_note):
			var t := float(i) / float(MIX_RATE)
			var envelope := 1.0 - float(i) / float(samples_per_note)
			var raw := sin(TAU * freq * t)
			if wave == "square":
				raw = 1.0 if raw >= 0.0 else -1.0
			var sample := clampf(raw * amplitude * envelope, -1.0, 1.0)
			data.encode_s16((note_index * samples_per_note + i) * 2, int(sample * 32767.0))

	var wav := _make_wav(total_samples)
	wav.data = data
	return wav


func _noise_burst(duration: float, amplitude: float) -> AudioStreamWAV:
	var sample_count := int(MIX_RATE * duration)
	var data := PackedByteArray()
	data.resize(sample_count * 2)

	for i in range(sample_count):
		var envelope := 1.0 - float(i) / float(sample_count)
		var sample := clampf((rng.randf() * 2.0 - 1.0) * amplitude * envelope, -1.0, 1.0)
		data.encode_s16(i * 2, int(sample * 32767.0))

	var wav := _make_wav(sample_count)
	wav.data = data
	return wav
