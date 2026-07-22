vec3 displacement(vec3 vertex, vec3 normal, float height, float heightOffset, float heightScale){
        return vertex += normal * (height - heightOffset) * heightScale;
}