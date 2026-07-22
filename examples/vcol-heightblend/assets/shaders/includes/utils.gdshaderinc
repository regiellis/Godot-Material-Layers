float saturate(float v) {
    return clamp(v, 0.0, 1.0);
}
vec2 saturate2(vec2 v) {
    return clamp(v, 0.0, 1.0);
}
vec3 saturate3(vec3 v) {
    return clamp(v, 0.0, 1.0);
}  
vec4 saturate4(vec4 v) {
    return clamp(v, 0.0, 1.0);
}
vec4 switch4(vec4 a, vec4 b, bool x){
    switch(int(x)){
        case 0: return a;
        case 1: return b;
    }
}
vec3 switch3(vec3 a, vec3 b, bool x){
    switch(int(x)){
        case 0: return a;
        case 1: return b;
    }
}
vec2 switch2(vec2 a, vec2 b, bool x){
    switch(int(x)){
        case 0: return a;
        case 1: return b;
    }
}
float switchF(float a, float b, bool x){
    switch(int(x)){
        case 0: return a;
        case 1: return b;
    }
}
float hashNoise( float p ) {
	vec3 v = vec3(p);
    v *= mat3(vec3(127.1, 311.7, -53.7), vec3(269.5, 183.3, 77.1), vec3(-301.7, 27.3, 215.3));
	return (2.0 * fract(fract(v) * 4375.55) -1.0).x;
}
vec3 hashNoise3( vec3 p ) {
	p *= mat3(vec3(127.1, 311.7, -53.7), vec3(269.5, 183.3, 77.1), vec3(-301.7, 27.3, 215.3));
	return 2.0 * fract(fract(p)*4375.55) -1.0;
}
float randVal( float seed_in, float min_val, float max_val) {
	vec3 seed = vec3(seed_in);
	seed *= mat3(vec3(127.1, 311.7, -53.7), vec3(269.5, 183.3, 77.1), vec3(-301.7, 27.3, 215.3));
	vec3 val = 2.0 * fract(fract(seed)*4375.55) -1.;
	float randomVal = mix(min_val, max_val, val.x);
	return randomVal;
}
vec3 randVal3( vec3 seed_in, float min_val, float max_val) {
	vec3 seed = seed_in;
    seed *= mat3(vec3(127.1, 311.7, -53.7), vec3(269.5, 183.3, 77.1), vec3(-301.7, 27.3, 215.3));
	vec3 val = 2.0 * fract(fract(seed)*4375.55) -1.;
	vec3 randomVal = mix(vec3(min_val), vec3(max_val), val);
	return randomVal;
}
float randValStep( float seed_in, float min_val, float max_val, float stepping) {
	vec3 seed = vec3(seed_in);
	seed *= mat3(vec3(127.1, 311.7, -53.7), vec3(269.5, 183.3, 77.1), vec3(-301.7, 27.3, 215.3));
	vec3 val = 2.0 * fract(fract(seed)*4375.55) -1.;
	float randomVal = mix(min_val, max_val, val.x);
	return floor(randomVal/stepping) * stepping;
}
vec3 randValStep3( vec3 seed_in, vec3 min_val, vec3 max_val, vec3 stepping) {
	vec3 seed = vec3(seed_in);
	seed *= mat3(vec3(127.1, 311.7, -53.7), vec3(269.5, 183.3, 77.1), vec3(-301.7, 27.3, 215.3));
	vec3 val = 2.0 * fract(fract(seed)*4375.55) -1.;
	vec3 randomVal = mix(min_val, max_val, val.x);
	return floor(randomVal/stepping) * stepping;
}
float fresnel(vec3 normal, vec3 view, bool invert, float power){
	float fresnel = pow(1.0 - clamp(dot(normal, view), 0.0, 1.0), power);
	fresnel = mix(fresnel, 1.0 - fresnel, float(invert));
    return fresnel;
}
float getChannel(vec4 tex, int ch) {
	if (ch == 0) return tex.r;
	if (ch == 1) return tex.g;
	if (ch == 2) return tex.b;
	if (ch == 3) return tex.a;
	return 1.0;
}