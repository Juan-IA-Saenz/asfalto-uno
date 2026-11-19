shader_type spatial;
uniform vec4 dye : source_color = vec4(0.7,0.36,0.19,1.0);
uniform int pattern = 0;
varying vec3 piece;
void vertex() { piece = VERTEX; }
void fragment() {
	vec2 p = vec2(piece.x + piece.z*0.37,piece.y);
	vec2 weave = p*vec2(460.0,355.0);
	weave.x += mod(floor(weave.y),2.0)*0.5;
	vec2 gap = abs(fract(weave)-0.5);
	float filtered = 1.0-smoothstep(0.27,0.85,max(fwidth(weave.x),fwidth(weave.y)));
	float mesh_dot = (1.0-smoothstep(0.14,0.30,length(gap))) * filtered;
	float fold = sin(p.y*63.0+sin(p.x*30.0)*1.3)*0.026 + sin(p.x*50.0+p.y*28.0)*0.024;
	float motif = 0.0;
	if (pattern == 1) {
		motif = step(0.69,fract((piece.y + piece.x*0.36)*12.0))*0.13;
	} else if (pattern == 2) {
		motif = smoothstep(0.102,0.169,abs(piece.x))*0.38;
	} else if (pattern == 3) {
		motif = step(0.955,fract(piece.x*44.0))*0.29;
	} else if (pattern == 4) {
		motif = 0.16 * smoothstep(0.39,0.43,piece.y + abs(piece.x)*0.40);
	} else if (pattern == 5) {
		motif = smoothstep(0.95,1.55,sin(piece.x*70.0)+cos(piece.y*70.0))*0.15;
	}
	ALBEDO = dye.rgb*(0.95 + fold - mesh_dot*0.22 - motif);
	ROUGHNESS = 0.83;
}
