extends CanvasLayer
## Виньетка по краям экрана и пыль в воздухе. Виньетка густеет и краснеет, когда рядом враг.

const SHADER_CODE := """
shader_type canvas_item;
uniform float tension = 0.0;
void fragment() {
    vec2 uv = UV - vec2(0.5);
    uv.x *= 1.1;
    float d = length(uv);
    float a = smoothstep(0.28, 0.78, d) * (0.55 + 0.35 * tension);
    vec3 tint = mix(vec3(0.0, 0.0, 0.02), vec3(0.14, 0.0, 0.02), tension);
    COLOR = vec4(tint, a);
}
"""

var _mat: ShaderMaterial


func _ready() -> void:
	layer = 4
	var rect := ColorRect.new()
	rect.size = Vector2(480, 270)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER_CODE
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	rect.material = _mat
	add_child(rect)
	_make_dust()


func set_tension(v: float) -> void:
	_mat.set_shader_parameter("tension", v)


# Пыль живёт в координатах экрана (на отдельном слое), поэтому видна и в тёмной комнате
func _make_dust() -> void:
	var p := CPUParticles2D.new()
	p.position = Vector2(240, 135)
	p.amount = 36
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(250, 140)
	p.direction = Vector2(1, -0.3)
	p.spread = 60.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 7.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.5
	p.color = Color(0.85, 0.8, 0.95, 0.35)
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.5, Color(1, 1, 1, 1))
	p.color_ramp = g
	add_child(p)
	p.emitting = true
