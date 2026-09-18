class_name Shot extends RefCounted

# Datos de un disparo, compartidos entre proyectil y láser hitscan.

var direction: Vector2 = Vector2.ZERO
var damage: int = 0
var speed: float = 0.0
var lifetime: float = 0.0
var knockback: float = 0.0
var pierce: int = 0
var wall_pierce: int = 0
var bounces: int = 0
var gravity: float = 0.0
var drag: float = 0.0
var stun_duration: float = 0.0
var ricochet_bonus: float = 0.0
var can_split: bool = false
var is_glitch: bool = false
var phantom: bool = false

var hit_position: Vector2 = Vector2.ZERO
var hit_normal: Vector2 = Vector2.ZERO

var visual: CanvasItem = null

func copy() -> Shot:
	var s := Shot.new()
	s.direction = direction
	s.damage = damage
	s.speed = speed
	s.lifetime = lifetime
	s.knockback = knockback
	s.pierce = pierce
	s.wall_pierce = wall_pierce
	s.bounces = bounces
	s.gravity = gravity
	s.drag = drag
	s.stun_duration = stun_duration
	s.ricochet_bonus = ricochet_bonus
	s.can_split = can_split
	s.is_glitch = is_glitch
	s.phantom = phantom
	s.hit_position = hit_position
	s.hit_normal = hit_normal
	s.visual = visual
	return s
