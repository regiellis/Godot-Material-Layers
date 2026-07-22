shader_type spatial;

#include "res://addons/materialLayers/shaders/layer_lib.gdshaderinc"
#include "res://assets/shaders/includes/height_blend.gdshaderinc"
#include "res://assets/shaders/includes/normal_map.gdshaderinc"
#include "res://assets/shaders/includes/utils.gdshaderinc"

varying vec3 localPos;
varying vec3 worldPos;

group_uniforms heightBlending;
uniform int vertexColor : hint_enum("Red", "Green", "Blue", "Alpha", "None") = 0;
uniform float heightOffset : hint_range(0.0, 1.0) = 0.2;
uniform float heightContrast : hint_range(0.0, 1.0) = 0.2;
uniform bool invertHeight;

void vertex() {
	SETUP_LAYER_VERTEX;

	localPos = VERTEX;
    worldPos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).rgb;

    float vertex_color = getChannel(COLOR, vertexColor);

    
    float mask = heightBlend(
            mix(1.0 - LAYER_BELOW_HEIGHT, LAYER_BELOW_HEIGHT, float(invertHeight)),
            LAYER_CURRENT_HEIGHT,
            heightOffset,
            heightContrast,
            vertex_color);
    
    // RESULT_VERTEX = LAYER_BELOW_VERTEX;
    RESULT_VERTEX = LAYER_BELOW_VERTEX + (LAYER_CURRENT_VERTEX - VERTEX) * mask;

}

void fragment() {
    
    SETUP_LAYER_FRAGMENT;

    //-------------------------------------

    float vertex_color = getChannel(COLOR, vertexColor);

    float mask = heightBlend(
        mix(1.0 - LAYER_BELOW_HEIGHT,
        LAYER_BELOW_HEIGHT, float(invertHeight)),
        LAYER_CURRENT_HEIGHT, heightOffset,
        heightContrast, vertex_color);

    //-------------------------------------

    RESULT_ALBEDO = mix(LAYER_BELOW_ALBEDO, LAYER_CURRENT_ALBEDO, mask);
    RESULT_ROUGHNESS = mix(LAYER_BELOW_ROUGHNESS, LAYER_CURRENT_ROUGHNESS, mask);
    RESULT_NORMAL_MAP = normalCombine(LAYER_BELOW_NORMAL_MAP, LAYER_CURRENT_NORMAL_MAP, mask);
    RESULT_AO = LAYER_BELOW_AO * mix(1.0, LAYER_CURRENT_AO, mask);
    RESULT_HEIGHT = LAYER_BELOW_HEIGHT;

}
