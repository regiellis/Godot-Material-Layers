vec3 normalCombine(vec3 n1, vec3 n2){
	return vec3(n1.rg + ((n2.rg - 0.5)), n1.z * n2.z);
}
vec3 normalCombine(vec3 n1, vec3 n2, float mask){
    vec2 blendedXY = n1.rg + (n2.rg - 0.5) * mask;
    float blendedZ = mix(n1.z, n1.z * n2.z, mask);
    return vec3(blendedXY, blendedZ);
}
vec3 normalStrength(vec3 normal_map_in, float normal_map_strength){
	vec3 normal = vec3(normal_map_in * 2.0 - 1.0);
	return vec3(normal.xy * normal_map_strength, normal.z) * 0.5 + 0.5;
}
vec3 normalInvert (vec3 normal_map){
    return vec3(1.0 - normal_map.xy, normal_map.z);
}
vec3 worldNormalMap(vec3 normal_map, mat4 inv_view_matrix, vec3 tangent, vec3 binormal, vec3 normal){		
	normal_map = normal_map * 2.0 - 1.0;
    vec3 tangentWS = (inv_view_matrix * vec4(tangent, 0.0)).xyz;
	vec3 binormalWS = vec3((inv_view_matrix * vec4(binormal, 0.0)).xyz);
	vec3 normalWS = vec3((inv_view_matrix * vec4(normal, 0.0)).xyz);
		
	mat4 TBN = mat4(vec4(tangentWS, 0.0), vec4(binormalWS, 0.0), vec4(normalWS, 0.0), vec4(0.0, 0.0, 0.0, 1.0));
	vec3 worldNormalMap = (TBN * vec4(normal_map, 1.0)).xyz;
    return worldNormalMap * 0.5 + 0.5;
}
vec3 deriveZ(float x_in, float y_in){
    vec2 normalXY = vec2(x_in * 2.0 - 1.0, y_in * 2.0 - 1.0);
	float z = sqrt(max(1.0 - dot(normalXY, normalXY), 0.0));
	vec3 normal = vec3(normalXY.x, normalXY.y, z);
	return normal * 0.5 + 0.5;
}

// vec3 rotateNormal(vec3 normal, float angle) {
//     normal = normal * 2.0 - 1.0;
    
//     float c = cos(angle);
//     float s = sin(angle);
    
//     float x = normal.x * c - normal.y * -s;
//     float y = normal.x * s + normal.y * c;

//     return vec3(x, y, normal.z) * 0.5 + 0.5;
// }

vec3 rotateNormal(vec3 normal, float angle) {
	normal = normal * 2.0 - 1.0;
	float rot = radians(-angle / 2.0);

	float c_x = cos(rot);
	float s_x = sin(rot);
	vec2 x_ = vec2(c_x, s_x);

	float c_y = cos(rot + PI / 2.0);
	float s_y = sin(rot + PI / 2.0);
	vec2 y_ = vec2(c_y, s_y);

	float x = dot(normal.xy, x_);
	float y = dot(normal.xy, y_);

	return vec3(x, y, normal.z) * 0.5 + 0.5;
    
}

vec2 rotatePackedNormal(vec2 normal, float angle) {
	normal = normal * 2.0 - 1.0;
	float rot = radians(-angle / 2.0);

	float c_x = cos(rot);
	float s_x = sin(rot);
	vec2 x_ = vec2(c_x, s_x);

	float c_y = cos(rot + PI / 2.0);
	float s_y = sin(rot + PI / 2.0);
	vec2 y_ = vec2(c_y, s_y);

	float x = dot(normal.xy, x_);
	float y = dot(normal.xy, y_);

	return vec2(x, y) * 0.5 + 0.5;
}