shader_type spatial;
uniform vec4 tint : source_color = vec4(0.51,0.35,0.31,1.0);
uniform float brick_amount = 1.0;
varying vec3 world_pos;
varying vec3 front;

float rand2(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7))) * 43758.5453); }
float smooth_noise(vec2 p) {
	vec2 a = floor(p), f = smoothstep(0.0,1.0,fract(p));
	return mix(mix(rand2(a),rand2(a+vec2(1,0)),f.x),mix(rand2(a+vec2(0,1)),rand2(a+vec2(1)),f.x),f.y);
}
void vertex() {
	world_pos = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
	front = normalize(MODEL_NORMAL_MATRIX*NORMAL);
}
void fragment() {
	vec2 p = vec2(abs(front.x)>0.5 ? world_pos.z : world_pos.x,world_pos.y);
	vec2 scale = p*vec2(3.4,11.4);
	scale.x += mod(floor(scale.y),2.0)*0.5;
	vec2 f = min(fract(scale),1.0-fract(scale));
	vec2 pix = min(fwidth(scale)*0.66,vec2(0.39));
	vec2 mortar = 1.0-smoothstep(vec2(0.026,0.048)-pix,vec2(0.026,0.048)+pix+0.0001,f);
	float grout = max(mortar.x,mortar.y)*brick_amount*(1.0-smoothstep(0.28,1.0,max(pix.x,pix.y)*2.0));
	float grain = smooth_noise(p*vec2(42.0,53.0));
	float cloud = smooth_noise(p*vec2(2.0,1.7));
	float tone = 0.77 + grain*0.14 + cloud*0.17 + rand2(floor(scale))*0.12*brick_amount;
	float damp = 0.70 + smoothstep(-0.14,1.52,world_pos.y + cloud*0.42)*0.30;
	vec3 masonry = tint.rgb * tone;
	ALBEDO = mix(masonry,mix(tint.rgb,vec3(0.56,0.50,0.45),0.40)*0.76,grout) * damp;
	ROUGHNESS = 0.92;
}
