shader_type spatial;

uniform vec4 tint : source_color = vec4(0.26, 0.31, 0.29, 1.0);
uniform float grain = 0.23;
uniform float scale = 150.0;
uniform float crack = 0.45;
varying vec3 point;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453); }
float noise2(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x), mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() { point = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz; }
void fragment() {
	vec2 p = point.xz + vec2(point.y*0.73, point.y*0.91);
	vec2 footprint = fwidth(p*scale);
	float grit = mix(noise2(p*scale),0.5,smoothstep(0.30,1.65,max(footprint.x,footprint.y)));
	float fade = noise2(p*0.76) * 0.21 + noise2(p*9.57) * 0.10;
	float fissure = 1.0 - smoothstep(0.006,0.019,abs(noise2(p*0.68+noise2(p*4.7)*0.21)-0.5));
	float scattered = smoothstep(0.70,0.95,noise2(p*2.0))*0.13;
	ALBEDO = tint.rgb * (0.76 + grain*(grit-0.28) + fade - fissure*crack + scattered);
	ROUGHNESS = 0.93 - grit*0.20;
}
