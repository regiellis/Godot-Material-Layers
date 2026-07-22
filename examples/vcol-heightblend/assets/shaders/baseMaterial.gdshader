shader_type spatial;
#include "res://addons/materialLayers/shaders/layer_lib.gdshaderinc"
#include "res://assets/shaders/includes/normal_map.gdshaderinc"
#include "res://assets/shaders/includes/displacement.gdshaderinc"
#include "res://assets/shaders/includes/height_blend.gdshaderinc"

group_uniforms displacement;
uniform float dispStrength = 0.0;
uniform float heightOffset_d = 0.5;


group_uniforms UVControls;
uniform float UVScale = 1.0;
uniform vec2 UVOffset = vec2(0.0, 0.0);
uniform float UVRot : hint_range(0.0, 360.0) = 0.0;
uniform vec2 pivot = vec2(0.0, 0.0);

group_uniforms albedo;
uniform vec3 tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float albedoBrightness : hint_range(-1.0, 1.0) = 0.0;
uniform float albedoContrast : hint_range(-1.0, 1.0) = 0.0;

group_uniforms roughness;
uniform float roughnessLevel : hint_range(-1.0, 1.0) = 0.0;
uniform float roughnessContrast : hint_range(-1.0, 2.0) = 0.0;

group_uniforms normal;
uniform float normalIntensity : hint_range(0.0, 5.0) = 1.0;

group_uniforms ao;
uniform float aoLevel : hint_range(-1.0, 1.0) = 0.0;

group_uniforms textures;
uniform sampler2D baseRough : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normAOHeight : filter_linear_mipmap_anisotropic;

void vertex() {
	
	SETUP_LAYER_VERTEX;

	//-------------------------------------

	float height = texture(normAOHeight, UV).a;	
	vec3 displacement = displacement(VERTEX, NORMAL, height, heightOffset_d, dispStrength);
	
	//-------------------------------------

	LAYER_OUT_HEIGHT = height;
	LAYER_OUT_VERTEX = displacement;

}

void fragment() {

	SETUP_LAYER_FRAGMENT;

	//-------------------------------------

    vec2 uv = UV * UVScale;

	vec4 base_rough = texture(baseRough, uv);
	vec4 norm_ao_height = texture(normAOHeight, uv);

	vec3 albedo = base_rough.rgb;
	float roughness = base_rough.a;
	vec3 normal = deriveZ(norm_ao_height.r, norm_ao_height.g);
	float ao = norm_ao_height.b;
	float height = norm_ao_height.a;

	albedo *= tint;
	albedo = albedo * (albedoBrightness + 1.0);
	albedo = (albedo - 0.5) * max(albedoContrast + 1.0, 0.0) + 0.5;
	albedo = clamp(albedo, 0.0, 1.0);

	roughness = roughness + roughnessLevel;
	roughness = (roughness - 0.5) * max(roughnessContrast + 1.0, 0.0) + 0.5;

	normal = normalStrength(normal, normalIntensity);

	ao += aoLevel;
	ao = clamp(ao, 0.0, 1.0);

	//-------------------------------------

	LAYER_OUT_ALBEDO = albedo;
	LAYER_OUT_ROUGHNESS = roughness;
	LAYER_OUT_NORMAL_MAP = normal;
	LAYER_OUT_AO = ao;
	LAYER_OUT_HEIGHT = height;

	//-------------------------------------

	ALBEDO = albedo;
	ROUGHNESS = roughness;
	NORMAL_MAP = normal;
	AO = ao;
	
}