shader_type canvas_item;
// One shared material for the block. Coordinates and road ownership come from
// the generated chunk, independent of polygon splits, load order or global RNG.
uniform vec4 area;
uniform vec4 road_h;
uniform vec4 road_v;
uniform vec2 ground_origin;
uniform vec2 chunk_extent;
uniform vec2 plant_corner = vec2(-100000.0);
uniform vec3 road_source_tint = vec3(1.28,1.34,1.35);
uniform vec3 road_mid = vec3(0.52,0.55,0.54);
uniform float road_contrast = 0.29;
uniform float road_repeat = 152.0;
uniform sampler2D road_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D grass_texture : source_color, repeat_enable, filter_linear_mipmap;
uniform sampler2D soil_texture : source_color, repeat_enable, filter_linear_mipmap;
varying vec2 point;
float hash(ivec2 p) {
	// Integer lattice hashing keeps the same corner bit-identical when
	// approached from either neighboring cell on Compatibility GPUs.
	uvec2 q=uvec2(p);
	uint h=q.x*374761393u+q.y*668265263u+2246822519u;
	h=(h^(h>>13u))*1274126177u;
	return float(h^(h>>16u))/4294967295.0;
}
float noise(vec2 p) {
	ivec2 i=ivec2(floor(p));
	vec2 f=fract(p); f=f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+ivec2(1,0)),f.x),mix(hash(i+ivec2(0,1)),hash(i+ivec2(1,1)),f.x),f.y);
}
float distance_rect(vec2 p, vec4 r) {
	if(r.z<=r.x || r.w<=r.y) return 100000.0;
	vec2 q=abs(p-(r.xy+r.zw)*0.5)-(r.zw-r.xy)*0.5;
	return length(max(q,vec2(0)))+min(max(q.x,q.y),0.0);
}
float distance_road(vec2 p, vec4 r) {
	if(r.z<=r.x || r.w<=r.y) return 100000.0;
	// A lane reaching a chunk edge is an open continuation, not a cul-de-sac.
	if(chunk_extent.x>0.0) {
		if(r.x<=0.0) r.x-=2048.0;
		if(r.z>=chunk_extent.x) r.z+=2048.0;
		if(r.y<=0.0) r.y-=2048.0;
		if(r.w>=chunk_extent.y) r.w+=2048.0;
	}
	return distance_rect(p,r);
}
void vertex() { point=VERTEX; }
void fragment() {
	vec2 world=point+ground_origin;
	float broad=noise(world/143.0);
	float fine=noise(world/23.0);
	// Broad uneven shoulders, not cell-sized zigzags. Keep the lane centre clear.
	float wander=clamp((noise(world/620.0)-0.45)*92.0+(noise(world/170.0)-0.5)*8.0,-38.0,30.0);
	vec2 h_point=point+vec2(0,(noise(vec2(world.x/730.0,world.y/2000.0))-0.5)*28.0);
	vec2 v_point=point+vec2((noise(vec2(world.x/2000.0,world.y/730.0))-0.5)*28.0,0);
	float h_distance=distance_road(h_point,road_h), v_distance=distance_road(v_point,road_v);
	float join=max(64.0-abs(h_distance-v_distance),0.0)/64.0;
	float road_d=min(h_distance,v_distance)-join*join*16.0+wander;
	float outer_d=distance_rect(point,area)+(broad-0.5)*19.0;
	vec3 paving=mix(vec3(0.57,0.59,0.55),COLOR.rgb,0.43);
	float repair=smoothstep(0.61,0.76,noise(world/290.0));
	paving=mix(paving,vec3(0.49,0.53,0.49)+(paving-vec3(0.55))*0.60,repair*0.38);
	vec3 stones=texture(road_texture,world/road_repeat).rgb;
	// Soft small setts, never a strong outline around every stone.
	vec3 road=mix(road_mid,stones*road_source_tint,road_contrast);
	road+=vec3(0.025)*(broad-0.5);
	vec3 ground=mix(paving,road,1.0-smoothstep(-1.0,1.0,road_d));
	float gutter=smoothstep(-9.0,-4.0,road_d)*(1.0-smoothstep(0.0,3.0,road_d));
	ground=mix(ground,vec3(0.37,0.42,0.40),gutter*0.31);
	float curb=smoothstep(1.0,3.0,road_d)*(1.0-smoothstep(10.0,12.0,road_d));
	curb*=smoothstep(0.25,0.45,noise(world/59.0));
	ground=mix(ground,vec3(0.64,0.65,0.59),curb*0.60);
	// Drainage hardware stays at the real civic outlet instead of mirrored grates.
	vec3 grass=texture(grass_texture,world/320.0).rgb;
	grass=mix(vec3(0.28,0.35,0.25),grass*vec3(1.22,1.30,1.12),0.60);
	vec3 soil=mix(vec3(0.36,0.34,0.27),texture(soil_texture,world/300.0).rgb,0.36);
	// Grouped earth at eligible margins; no sandy border round every shape.
	float soil_patch=smoothstep(0.42,0.69,broad)*(1.0-smoothstep(18.0,75.0,abs(outer_d)));
	vec3 verge=mix(grass,soil,soil_patch*0.80);
	float growth=smoothstep(-14.0,28.0,outer_d+(fine-0.5)*13.0);
	float planted=(1.0-smoothstep(38.0,95.0,distance(point,plant_corner)))*(0.8+0.2*fine);
	growth=max(growth,planted*0.92);
	verge=mix(verge,soil,planted*0.65);
	// Road connectors stay open and paved right up to their generated ends.
	growth*=smoothstep(7.0,28.0,road_d);
	ground=mix(ground,verge,growth);
	// Broken ground-level edges instead of a translucent green fog round the block.
	float fringe=62.0+broad*42.0+(fine-0.5)*14.0;
	float pockets=smoothstep(0.48,0.66,noise(world/187.0));
	float alpha=(1.0-smoothstep(fringe-12.0,fringe+10.0,outer_d));
	alpha*=mix(1.0,pockets,smoothstep(-3.0,24.0,outer_d));
	// The paved road itself stays opaque at continuing chunk connectors.
	alpha=max(alpha,(1.0-smoothstep(0.0,8.0,road_d))*(1.0-smoothstep(70.0,112.0,outer_d)));
	// Return to the shared organic ground before crossing a streamed boundary.
	// This also prevents a straight painted frontage edge in the neighbor's grass.
	if(chunk_extent.x>0.0) {
		float chunk_edge=min(min(point.x,chunk_extent.x-point.x),min(point.y,chunk_extent.y-point.y));
		alpha*=smoothstep(0.0,96.0,chunk_edge);
	}
	COLOR=vec4(ground,alpha);
}
