shader_type spatial;

#include "res://addons/materialLayers/shaders/layer_lib.gdshaderinc"
#include "res://assets/shaders/includes/normal_map.gdshaderinc"
#include "res://assets/shaders/includes/displacement.gdshaderinc"
#include "res://assets/shaders/includes/height_blend.gdshaderinc"
#include "res://assets/shaders/includes/utils.gdshaderinc"



varying vec3 localPos;
varying vec3 worldPos;


uniform float s_layer_0_dispStrength = 0.0;
uniform float s_layer_0_heightOffset_d = 0.5;
uniform float s_layer_0_UVScale = 1.0;
uniform vec2 s_layer_0_UVOffset = vec2(0.0, 0.0);
uniform float s_layer_0_UVRot : hint_range(0.0, 360.0) = 0.0;
uniform vec2 s_layer_0_pivot = vec2(0.0, 0.0);
uniform vec3 s_layer_0_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float s_layer_0_albedoBrightness : hint_range(-1.0, 1.0) = 0.0;
uniform float s_layer_0_albedoContrast : hint_range(-1.0, 1.0) = 0.0;
uniform float s_layer_0_roughnessLevel : hint_range(-1.0, 1.0) = 0.0;
uniform float s_layer_0_roughnessContrast : hint_range(-1.0, 2.0) = 0.0;
uniform float s_layer_0_normalIntensity : hint_range(0.0, 5.0) = 1.0;
uniform float s_layer_0_aoLevel : hint_range(-1.0, 1.0) = 0.0;




uniform int m_layer_1_vertexColor : hint_enum("Red", "Green", "Blue", "Alpha", "None") = 0;
uniform float m_layer_1_heightOffset : hint_range(0.0, 1.0) = 0.2;
uniform float m_layer_1_heightContrast : hint_range(0.0, 1.0) = 0.2;
uniform bool m_layer_1_invertHeight;
uniform float s_layer_1_dispStrength = 0.0;
uniform float s_layer_1_heightOffset_d = 0.5;
uniform float s_layer_1_UVScale = 1.0;
uniform vec2 s_layer_1_UVOffset = vec2(0.0, 0.0);
uniform float s_layer_1_UVRot : hint_range(0.0, 360.0) = 0.0;
uniform vec2 s_layer_1_pivot = vec2(0.0, 0.0);
uniform vec3 s_layer_1_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float s_layer_1_albedoBrightness : hint_range(-1.0, 1.0) = 0.0;
uniform float s_layer_1_albedoContrast : hint_range(-1.0, 1.0) = 0.0;
uniform float s_layer_1_roughnessLevel : hint_range(-1.0, 1.0) = 0.0;
uniform float s_layer_1_roughnessContrast : hint_range(-1.0, 2.0) = 0.0;
uniform float s_layer_1_normalIntensity : hint_range(0.0, 5.0) = 1.0;
uniform float s_layer_1_aoLevel : hint_range(-1.0, 1.0) = 0.0;




uniform int m_layer_2_vertexColor : hint_enum("Red", "Green", "Blue", "Alpha", "None") = 0;
uniform float m_layer_2_heightOffset : hint_range(0.0, 1.0) = 0.2;
uniform float m_layer_2_heightContrast : hint_range(0.0, 1.0) = 0.2;
uniform bool m_layer_2_invertHeight;
uniform float s_layer_2_dispStrength = 0.0;
uniform float s_layer_2_heightOffset_d = 0.5;
uniform float s_layer_2_UVScale = 1.0;
uniform vec2 s_layer_2_UVOffset = vec2(0.0, 0.0);
uniform float s_layer_2_UVRot : hint_range(0.0, 360.0) = 0.0;
uniform vec2 s_layer_2_pivot = vec2(0.0, 0.0);
uniform vec3 s_layer_2_tint : source_color = vec3(1.0, 1.0, 1.0);
uniform float s_layer_2_albedoBrightness : hint_range(-1.0, 1.0) = 0.0;
uniform float s_layer_2_albedoContrast : hint_range(-1.0, 1.0) = 0.0;
uniform float s_layer_2_roughnessLevel : hint_range(-1.0, 1.0) = 0.0;
uniform float s_layer_2_roughnessContrast : hint_range(-1.0, 2.0) = 0.0;
uniform float s_layer_2_normalIntensity : hint_range(0.0, 5.0) = 1.0;
uniform float s_layer_2_aoLevel : hint_range(-1.0, 1.0) = 0.0;




uniform sampler2D s_layer_0_baseRough : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D s_layer_0_normAOHeight : filter_linear_mipmap_anisotropic;
uniform sampler2D s_layer_1_baseRough : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D s_layer_1_normAOHeight : filter_linear_mipmap_anisotropic;
uniform sampler2D s_layer_2_baseRough : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D s_layer_2_normAOHeight : filter_linear_mipmap_anisotropic;








void vertex() {

	vertexMaterial DEFAULT_VERTEX = vertexMaterial(
	    VERTEX,
		0.5
	);
		SETUP_LAYER_VERTEX;

	vertexMaterial vertex_0_out = DEFAULT_VERTEX;
	float s_layer_0_height = texture(s_layer_0_normAOHeight, UV).a;
	vec3 s_layer_0_displacement = displacement(VERTEX, NORMAL, s_layer_0_height, s_layer_0_heightOffset_d, s_layer_0_dispStrength);
	vertex_0_out.layer_mat_height = s_layer_0_height;
	vertex_0_out.layer_mat_vertex = s_layer_0_displacement;


	vertexMaterial finalVertex = vertex_0_out;

	finalVertex = vertex_0_out;
	vertexMaterial vertex_1_out = finalVertex;
	float s_layer_1_height = texture(s_layer_1_normAOHeight, UV).a;
	vec3 s_layer_1_displacement = displacement(VERTEX, NORMAL, s_layer_1_height, s_layer_1_heightOffset_d, s_layer_1_dispStrength);
	vertex_1_out.layer_mat_height = s_layer_1_height;
	vertex_1_out.layer_mat_vertex = s_layer_1_displacement;

	localPos = VERTEX;
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).rgb;
	float m_layer_1_vertex_color = getChannel(COLOR, m_layer_1_vertexColor);
	float m_layer_1_mask = heightBlend(
	            mix(1.0 - vertex_0_out.layer_mat_height, vertex_0_out.layer_mat_height, float(m_layer_1_invertHeight)),
	            vertex_1_out.layer_mat_height,
	            m_layer_1_heightOffset,
	            m_layer_1_heightContrast,
	            m_layer_1_vertex_color);
	finalVertex.layer_mat_vertex = vertex_0_out.layer_mat_vertex + (vertex_1_out.layer_mat_vertex - VERTEX) * m_layer_1_mask;

	vertexMaterial vertex_2_out = finalVertex;
	float s_layer_2_height = texture(s_layer_2_normAOHeight, UV).a;
	vec3 s_layer_2_displacement = displacement(VERTEX, NORMAL, s_layer_2_height, s_layer_2_heightOffset_d, s_layer_2_dispStrength);
	vertex_2_out.layer_mat_height = s_layer_2_height;
	vertex_2_out.layer_mat_vertex = s_layer_2_displacement;

	localPos = VERTEX;
	worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).rgb;
	float m_layer_2_vertex_color = getChannel(COLOR, m_layer_2_vertexColor);
	float m_layer_2_mask = heightBlend(
	            mix(1.0 - finalVertex.layer_mat_height, finalVertex.layer_mat_height, float(m_layer_2_invertHeight)),
	            vertex_2_out.layer_mat_height,
	            m_layer_2_heightOffset,
	            m_layer_2_heightContrast,
	            m_layer_2_vertex_color);
	finalVertex.layer_mat_vertex = finalVertex.layer_mat_vertex + (vertex_2_out.layer_mat_vertex - VERTEX) * m_layer_2_mask;

	
	VERTEX = finalVertex.layer_mat_vertex;
	}
void fragment() {


	layerData DEFAULT_LAYER_DATA = layerData(
	    vec4(0.0),
    	vec4(0.0),
    	vec4(0.0),
    	vec4(0.0),
    	vec4(0.0),
    	vec4(0.0),
    	vec4(0.0),
    	vec4(0.0),
    	0.0,
    	0.0,
    	0.0,
    	0.0,
    	0.0,
    	0.0,
    	0.0,
    	0.0
	);

	fragmentMaterial DEFAULT_FRAGMENT = fragmentMaterial(
	    vec3(0.75),               
	    vec3(0.5, 0.5, 1.0),      
	    1.0,                      
	    1.0,                      
	    0.5,                      
	    0.0,                      
	    vec3(0.0),                
	    vec3(0.5, 0.5, 1.0),    
	    vec3(0.5, 0.5, 1.0),      
	    1.0,                      
	    0.5,                      
	    0.0,                      
	    0.0                
	);
		SETUP_LAYER_FRAGMENT;

	layerData layer_0_data = DEFAULT_LAYER_DATA;
	fragmentMaterial fragment_0_out = DEFAULT_FRAGMENT;
	vec2 s_layer_0_uv = UV * s_layer_0_UVScale;
	vec4 s_layer_0_base_rough = texture(s_layer_0_baseRough, s_layer_0_uv);
	vec4 s_layer_0_norm_ao_height = texture(s_layer_0_normAOHeight, s_layer_0_uv);
	vec3 s_layer_0_albedo = s_layer_0_base_rough.rgb;
	float s_layer_0_roughness = s_layer_0_base_rough.a;
	vec3 s_layer_0_normal = deriveZ(s_layer_0_norm_ao_height.r, s_layer_0_norm_ao_height.g);
	float s_layer_0_ao = s_layer_0_norm_ao_height.b;
	float s_layer_0_height = s_layer_0_norm_ao_height.a;
	s_layer_0_albedo *= s_layer_0_tint;
	s_layer_0_albedo = s_layer_0_albedo * (s_layer_0_albedoBrightness + 1.0);
	s_layer_0_albedo = (s_layer_0_albedo - 0.5) * max(s_layer_0_albedoContrast + 1.0, 0.0) + 0.5;
	s_layer_0_albedo = clamp(s_layer_0_albedo, 0.0, 1.0);
	s_layer_0_roughness = s_layer_0_roughness + s_layer_0_roughnessLevel;
	s_layer_0_roughness = (s_layer_0_roughness - 0.5) * max(s_layer_0_roughnessContrast + 1.0, 0.0) + 0.5;
	s_layer_0_normal = normalStrength(s_layer_0_normal, s_layer_0_normalIntensity);
	s_layer_0_ao += s_layer_0_aoLevel;
	s_layer_0_ao = clamp(s_layer_0_ao, 0.0, 1.0);
	fragment_0_out.layer_mat_albedo = s_layer_0_albedo;
	fragment_0_out.layer_mat_roughness = s_layer_0_roughness;
	fragment_0_out.layer_mat_normal_map = s_layer_0_normal;
	fragment_0_out.layer_mat_ao = s_layer_0_ao;
	fragment_0_out.layer_mat_height = s_layer_0_height;


	layerData finalLayerData = layer_0_data;


	fragmentMaterial finalFragment = fragment_0_out;

	finalLayerData = layer_0_data;

	finalFragment = fragment_0_out;
	layerData layer_1_data = finalLayerData;
	fragmentMaterial fragment_1_out = finalFragment;
	vec2 s_layer_1_uv = UV * s_layer_1_UVScale;
	vec4 s_layer_1_base_rough = texture(s_layer_1_baseRough, s_layer_1_uv);
	vec4 s_layer_1_norm_ao_height = texture(s_layer_1_normAOHeight, s_layer_1_uv);
	vec3 s_layer_1_albedo = s_layer_1_base_rough.rgb;
	float s_layer_1_roughness = s_layer_1_base_rough.a;
	vec3 s_layer_1_normal = deriveZ(s_layer_1_norm_ao_height.r, s_layer_1_norm_ao_height.g);
	float s_layer_1_ao = s_layer_1_norm_ao_height.b;
	float s_layer_1_height = s_layer_1_norm_ao_height.a;
	s_layer_1_albedo *= s_layer_1_tint;
	s_layer_1_albedo = s_layer_1_albedo * (s_layer_1_albedoBrightness + 1.0);
	s_layer_1_albedo = (s_layer_1_albedo - 0.5) * max(s_layer_1_albedoContrast + 1.0, 0.0) + 0.5;
	s_layer_1_albedo = clamp(s_layer_1_albedo, 0.0, 1.0);
	s_layer_1_roughness = s_layer_1_roughness + s_layer_1_roughnessLevel;
	s_layer_1_roughness = (s_layer_1_roughness - 0.5) * max(s_layer_1_roughnessContrast + 1.0, 0.0) + 0.5;
	s_layer_1_normal = normalStrength(s_layer_1_normal, s_layer_1_normalIntensity);
	s_layer_1_ao += s_layer_1_aoLevel;
	s_layer_1_ao = clamp(s_layer_1_ao, 0.0, 1.0);
	fragment_1_out.layer_mat_albedo = s_layer_1_albedo;
	fragment_1_out.layer_mat_roughness = s_layer_1_roughness;
	fragment_1_out.layer_mat_normal_map = s_layer_1_normal;
	fragment_1_out.layer_mat_ao = s_layer_1_ao;
	fragment_1_out.layer_mat_height = s_layer_1_height;

	float m_layer_1_vertex_color = getChannel(COLOR, m_layer_1_vertexColor);
	float m_layer_1_mask = heightBlend(
	        mix(1.0 - fragment_0_out.layer_mat_height,
	        fragment_0_out.layer_mat_height, float(m_layer_1_invertHeight)),
	        fragment_1_out.layer_mat_height, m_layer_1_heightOffset,
	        m_layer_1_heightContrast, m_layer_1_vertex_color);
	finalFragment.layer_mat_albedo = mix(fragment_0_out.layer_mat_albedo, fragment_1_out.layer_mat_albedo, m_layer_1_mask);
	finalFragment.layer_mat_roughness = mix(fragment_0_out.layer_mat_roughness, fragment_1_out.layer_mat_roughness, m_layer_1_mask);
	finalFragment.layer_mat_normal_map = normalCombine(fragment_0_out.layer_mat_normal_map, fragment_1_out.layer_mat_normal_map, m_layer_1_mask);
	finalFragment.layer_mat_ao = fragment_0_out.layer_mat_ao * mix(1.0, fragment_1_out.layer_mat_ao, m_layer_1_mask);
	finalFragment.layer_mat_height = fragment_0_out.layer_mat_height;
	finalLayerData = layer_1_data;


	layerData layer_2_data = finalLayerData;
	fragmentMaterial fragment_2_out = finalFragment;
	vec2 s_layer_2_uv = UV * s_layer_2_UVScale;
	vec4 s_layer_2_base_rough = texture(s_layer_2_baseRough, s_layer_2_uv);
	vec4 s_layer_2_norm_ao_height = texture(s_layer_2_normAOHeight, s_layer_2_uv);
	vec3 s_layer_2_albedo = s_layer_2_base_rough.rgb;
	float s_layer_2_roughness = s_layer_2_base_rough.a;
	vec3 s_layer_2_normal = deriveZ(s_layer_2_norm_ao_height.r, s_layer_2_norm_ao_height.g);
	float s_layer_2_ao = s_layer_2_norm_ao_height.b;
	float s_layer_2_height = s_layer_2_norm_ao_height.a;
	s_layer_2_albedo *= s_layer_2_tint;
	s_layer_2_albedo = s_layer_2_albedo * (s_layer_2_albedoBrightness + 1.0);
	s_layer_2_albedo = (s_layer_2_albedo - 0.5) * max(s_layer_2_albedoContrast + 1.0, 0.0) + 0.5;
	s_layer_2_albedo = clamp(s_layer_2_albedo, 0.0, 1.0);
	s_layer_2_roughness = s_layer_2_roughness + s_layer_2_roughnessLevel;
	s_layer_2_roughness = (s_layer_2_roughness - 0.5) * max(s_layer_2_roughnessContrast + 1.0, 0.0) + 0.5;
	s_layer_2_normal = normalStrength(s_layer_2_normal, s_layer_2_normalIntensity);
	s_layer_2_ao += s_layer_2_aoLevel;
	s_layer_2_ao = clamp(s_layer_2_ao, 0.0, 1.0);
	fragment_2_out.layer_mat_albedo = s_layer_2_albedo;
	fragment_2_out.layer_mat_roughness = s_layer_2_roughness;
	fragment_2_out.layer_mat_normal_map = s_layer_2_normal;
	fragment_2_out.layer_mat_ao = s_layer_2_ao;
	fragment_2_out.layer_mat_height = s_layer_2_height;

	float m_layer_2_vertex_color = getChannel(COLOR, m_layer_2_vertexColor);
	float m_layer_2_mask = heightBlend(
	        mix(1.0 - finalFragment.layer_mat_height,
	        finalFragment.layer_mat_height, float(m_layer_2_invertHeight)),
	        fragment_2_out.layer_mat_height, m_layer_2_heightOffset,
	        m_layer_2_heightContrast, m_layer_2_vertex_color);
	finalFragment.layer_mat_albedo = mix(finalFragment.layer_mat_albedo, fragment_2_out.layer_mat_albedo, m_layer_2_mask);
	finalFragment.layer_mat_roughness = mix(finalFragment.layer_mat_roughness, fragment_2_out.layer_mat_roughness, m_layer_2_mask);
	finalFragment.layer_mat_normal_map = normalCombine(finalFragment.layer_mat_normal_map, fragment_2_out.layer_mat_normal_map, m_layer_2_mask);
	finalFragment.layer_mat_ao = finalFragment.layer_mat_ao * mix(1.0, fragment_2_out.layer_mat_ao, m_layer_2_mask);
	finalFragment.layer_mat_height = finalFragment.layer_mat_height;
	finalLayerData = layer_2_data;


	
	ALBEDO = finalFragment.layer_mat_albedo;
	NORMAL_MAP = l_normalCombine(finalFragment.layer_mat_normal_map, finalFragment.layer_mat_mesh_normal_map);
	BENT_NORMAL_MAP = finalFragment.layer_mat_bent_normal;
	ROUGHNESS = finalFragment.layer_mat_roughness;
	AO = finalFragment.layer_mat_ao * finalFragment.layer_mat_mesh_ao;
	METALLIC = finalFragment.layer_mat_metallic;
	EMISSION = finalFragment.layer_mat_emission;
	}