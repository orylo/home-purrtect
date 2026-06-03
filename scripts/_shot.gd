extends Node2D
func _ready():
	GameState.cleared_stages=[3,5,7]; GameState.coachmark_seen=["prep","pearl","max"]
	GameState.mode="player"; GameState.stage_major=1; GameState.stage_minor=8; GameState.coins=3154996
	get_tree().change_scene_to_file.call_deferred("res://scenes/home.tscn")
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	var img = get_viewport().get_texture().get_image()
	img.save_png("/tmp/home_shot.png")
	print("saved")
	get_tree().quit()
