shader_type spatial;

varying vec3 panel;
float rand(vec2 p) { return fract(sin(dot(p,vec2(12.9898,78.233))) * 43758.5453); }
void vertex() { panel = normalize(VERTEX); }
void fragment() {
	vec3 p = normalize(panel);
	float seam = min(min(abs(p.x),abs(p.z)), min(abs(p.y - 0.59*sin(p.x*2.7)), abs(p.y + 0.59*sin(p.x*2.7))));
	float dots = rand(floor(vec2(atan(p.z,p.x),p.y)*182.0));
	float channel = 1.0-smoothstep(0.019,0.032,seam);
	ALBEDO = mix(vec3(0.74,0.287,0.101)*(0.83+dots*0.23),vec3(0.052,0.037,0.034),channel);
	ROUGHNESS = 0.78+dots*0.14;
}
