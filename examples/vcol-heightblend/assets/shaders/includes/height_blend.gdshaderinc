
float heightBlend(float h1, float h2, float height_offset, float contrast, float mask){
	height_offset = 1.0 - height_offset;
    float add1 = h1 + height_offset;
	float subtract1 = h2 - height_offset;
    float add2 = subtract1 + mask;
	float max1 = max(add1, add2);
	float subtract2 = max1 - add1;
	float multiply1 = subtract2 * (contrast * 30.0);
    float result = clamp(multiply1, 0.0, 1.0);
	return result;
}