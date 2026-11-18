extends Control
## Setinha "▷" do menu, desenhada em pixels.

const FILL := Color("fff8ec")
const OUTLINE := Color("8a5f4a")


func _draw() -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-1, -1), Vector2(8, 5), Vector2(-1, 11)]), OUTLINE)
	draw_colored_polygon(PackedVector2Array([Vector2(1, 2), Vector2(5, 5), Vector2(1, 8)]), FILL)
