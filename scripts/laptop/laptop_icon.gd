class_name LaptopIcon
extends Control
## A little picture on the laptop, drawn in flat blocks like an old 32 x 32
## icon (scaled up): a booster pack for the Card Shop, a binder for My
## Collection, a toolbox for Tools, a notepad for To Do, a page for Instructions, an "i" for a
## message box, and the Start button's mark (a card back's oval).

const SIZE := 64.0

## Which picture: an app id (LaptopScreen.APPS), "info" or "start".
var kind := ""


func _draw() -> void:
	var u := size.x / 16.0 # One block of a 16 x 16 grid.
	var block := func(x: float, y: float, w: float, h: float, colour: Color) -> void:
		draw_rect(Rect2(x * u, y * u, w * u, h * u), colour)
	match kind:
		"shop":
			# A booster pack: crimped foil, a band of art, a star.
			block.call(3, 1, 10, 14, Color8(0, 0, 0))
			block.call(4, 2, 8, 12, Color8(200, 60, 30))
			block.call(4, 2, 8, 1, Color8(240, 200, 80))
			block.call(4, 13, 8, 1, Color8(240, 200, 80))
			block.call(5, 5, 6, 5, Color8(90, 50, 140))
			block.call(7, 6, 2, 3, Color8(255, 240, 160))
			block.call(6, 7, 4, 1, Color8(255, 240, 160))
		"collection":
			# A binder with three rings and a label.
			block.call(2, 1, 12, 14, Color8(0, 0, 0))
			block.call(3, 2, 10, 12, Color8(20, 100, 60))
			block.call(3, 2, 2, 12, Color8(10, 70, 40))
			for y in [4, 7, 10]:
				block.call(1, y, 3, 1, Color8(200, 200, 200))
			block.call(7, 5, 5, 3, Color8(230, 210, 140))
		"tools":
			# A wrench over a toolbox.
			block.call(1, 8, 14, 7, Color8(0, 0, 0))
			block.call(2, 9, 12, 5, Color8(180, 30, 30))
			block.call(2, 11, 12, 1, Color8(120, 20, 20))
			block.call(6, 6, 4, 3, Color8(0, 0, 0))
			block.call(7, 7, 2, 2, Color8(180, 30, 30))
			block.call(3, 2, 3, 3, Color8(200, 200, 200))
			block.call(4, 3, 1, 1, Color8(0, 128, 128))
			block.call(5, 4, 7, 2, Color8(160, 160, 160))
		"story":
			# A notepad: lined page under a spiral.
			block.call(3, 2, 10, 13, Color8(0, 0, 0))
			block.call(4, 3, 8, 11, Color8(255, 255, 255))
			for x in [5, 7, 9, 11]:
				block.call(x - 0.5, 1, 1, 3, Color8(128, 128, 128))
			for y in [6, 8, 10, 12]:
				block.call(5, y, 6, 1, Color8(100, 120, 220))
		"readme":
			# A page with its corner folded, and lines of text.
			block.call(3, 1, 10, 14, Color8(0, 0, 0))
			block.call(4, 2, 8, 12, Color8(255, 255, 255))
			block.call(10, 2, 2, 2, Color8(192, 192, 192))
			for y in [5, 7, 9, 11]:
				block.call(5, y, 6 if y < 11 else 4, 1, Color8(0, 0, 0))
		"info":
			# A speech bubble with an "i".
			draw_circle(size / 2, size.x * 0.45, Color8(0, 0, 0))
			draw_circle(size / 2, size.x * 0.42, Color8(255, 255, 255))
			block.call(7, 3, 2, 2, Color8(0, 0, 160))
			block.call(7, 6, 2, 7, Color8(0, 0, 160))
			block.call(6, 12, 4, 1, Color8(0, 0, 160))
		"start":
			# A card back's oval, brown and blue.
			block.call(2, 0, 12, 16, Color8(110, 70, 30))
			draw_circle(size / 2, size.x * 0.32, Color8(30, 60, 140))
			draw_circle(size / 2, size.x * 0.18, Color8(200, 140, 60))
