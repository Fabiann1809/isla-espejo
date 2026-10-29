class_name Ambience
extends RefCounted
## The forest's overall look, added to a playable level: a light tint over the world and a screen
## pass with a little less saturation and a soft vignette. The HUD and menus are not affected.
## Everything is set (and can be switched off) in Tuning.

const GRADE_SHADER := """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float desaturation = 0.0;
uniform float vignette_strength = 0.0;
uniform float vignette_start = 0.6;
void fragment() {
	vec3 color = texture(screen_texture, SCREEN_UV).rgb;
	float grey = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(color, vec3(grey), desaturation);
	vec2 from_center = (SCREEN_UV - 0.5) * vec2(1.7778, 1.0);
	float reach = length(from_center) / length(vec2(0.8889, 0.5));
	color *= 1.0 - smoothstep(vignette_start, 1.0, reach) * vignette_strength;
	COLOR = vec4(color, 1.0);
}
"""


## Turns the look on or off for the scenario being played, creating its nodes the first time.
static func apply(level: Node, enabled: bool) -> void:
	if not level.has_node("WorldTint") and not level.has_node("ScreenGrade"):
		add_to(level)
	var tint := level.get_node_or_null("WorldTint") as CanvasModulate
	if tint != null:
		tint.visible = enabled
	var grade := level.get_node_or_null("ScreenGrade") as CanvasLayer
	if grade != null:
		grade.visible = enabled


static func add_to(level: Node) -> void:
	if Tuning.WORLD_TINT_ENABLED:
		var tint := CanvasModulate.new()
		tint.name = "WorldTint"
		tint.color = Tuning.WORLD_TINT
		level.add_child(tint)
	if Tuning.SCREEN_GRADE_ENABLED:
		# Same layer as the HUD but first among the level's children, so the HUD is drawn after it.
		var layer := CanvasLayer.new()
		layer.name = "ScreenGrade"
		level.add_child(layer)
		level.move_child(layer, 0)
		var rect := ColorRect.new()
		rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var shader := Shader.new()
		shader.code = GRADE_SHADER
		var material := ShaderMaterial.new()
		material.shader = shader
		material.set_shader_parameter("desaturation", Tuning.DESATURATION)
		material.set_shader_parameter("vignette_strength", Tuning.VIGNETTE_STRENGTH)
		material.set_shader_parameter("vignette_start", Tuning.VIGNETTE_START)
		rect.material = material
		layer.add_child(rect)
