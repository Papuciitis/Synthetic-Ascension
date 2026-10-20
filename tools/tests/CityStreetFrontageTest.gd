extends SceneTree

var failures := 0
var checks := 0

func check(ok: bool, note: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(note)

func _initialize() -> void:
	var script = load("res://scenes/world/buildings/CityStreetFrontage.gd")
	check(script != null, "S2 street frontage composer exists")
	if script != null:
		for direction: Vector2i in [Vector2i.DOWN,Vector2i.UP,Vector2i.LEFT,Vector2i.RIGHT]:
			var box := Rect2(320,320,512,512)
			var door := {"pos":Vector2i(9,12) if direction.y != 0 else Vector2i(12,9),"dir":direction,"width":2}
			var plans: Array = script.plan(box,[door],64,Rect2(0,0,2048,2048))
			check(not plans.is_empty(), "real cardinal entry receives an apron")
			for plan: Rect2 in plans:
				check(Rect2(0,0,2048,2048).encloses(plan), "apron stays in inspected chunk")
		var source := Rect2(280,280,720,720)
		var cuts: Array[Rect2] = [Rect2(320,320,512,512),Rect2(860,320,100,512)]
		var pieces: Array = script.subtract([source],cuts)
		for piece: Rect2 in pieces:
			for cut: Rect2 in cuts:
				check(piece.intersection(cut).get_area() < 0.01,"frontage excludes every real interior")
	print("CityStreetFrontageTest: checks=%d failures=%d" % [checks,failures])
	quit(1 if failures else 0)
