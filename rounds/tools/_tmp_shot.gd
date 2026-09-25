extends Node

func _ready() -> void:
    var sp := Sprite2D.new()
    sp.texture = load("res://sprite_sheets/Puerta.png")
    sp.hframes = 4
    sp.region_enabled = true
    sp.region_rect = Rect2(0, 1, 128, 24)
    sp.position = Vector2(0, 0)
    sp.scale = Vector2(1, 5.333333)
    add_child(sp)
    print("get_rect=", sp.get_rect(), " scale=", sp.scale, " region=", sp.region_rect)
    # Referencias: mundo -64 y +64 (deberian ser los bordes del frame dibujado)
    _linea(-64.0, Color(0,1,1))
    _linea(64.0, Color(0,1,1))
    var cam := Camera2D.new()
    cam.zoom = Vector2(4, 4)
    add_child(cam)
    cam.make_current()
    for i in 10:
        await get_tree().process_frame
    get_viewport().get_texture().get_image().save_png("C:/Users/adria/AppData/Local/Temp/opencode/iso.png")
    print("listo")
    get_tree().quit(0)

func _linea(y: float, col: Color) -> void:
    var p := Polygon2D.new()
    p.polygon = PackedVector2Array([Vector2(-40, y), Vector2(40, y), Vector2(40, y+1), Vector2(-40, y+1)])
    p.color = col
    add_child(p)
