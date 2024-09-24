#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.
uniform vec4 u_Color2;
uniform float u_Time;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;


out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

vec3 random3 ( vec3 p ) {
    return fract(sin(vec3(dot(p,vec3(127.1f, 311.7f, 191.9f)), dot(p,vec3(269.5f, 183.3f, 251.9f)),dot(p, vec3(420.6f, 631.2f, 311.9f))))* 43758.5453f);
}


float surflet(vec3 p, vec3 gridPoint) {
    // Compute the distance between p and the grid point along each axis, and warp it with a
    // quintic function so we can smooth our cells
    vec3 t2 = abs(p - gridPoint);
    vec3 t = vec3(1.f) - 6.f * pow(t2, vec3(5.f)) + 15.f * pow(t2, vec3(4.f)) - 10.f * pow(t2, vec3(3.f));
    // Get the random vector for the grid point (assume we wrote a function random2
    // that returns a vec2 in the range [0, 1])
    vec3 gradient = random3(gridPoint) * 2. - vec3(1., 1., 1.);
    // Get the vector from the grid point to P
    vec3 diff = p - gridPoint;
    // Get the value of our height field by dotting grid->P with our gradient
    float height = dot(diff, gradient);
    // Scale our height field (i.e. reduce it) by our polynomial falloff function
    return height * t.x * t.y * t.z;
}

float perlinNoise3D(vec3 p) {
	float surfletSum = 0.f;
	// Iterate over the four integer corners surrounding uv
	for(float dx = 0.f; dx <= 1.f; ++dx) {
		for(float dy = 0.f; dy <= 1.f; ++dy) {
			for(float dz = 0.f; dz <= 1.f; ++dz) {
				surfletSum += surflet(p, floor(p) + vec3(dx, dy, dz));
			}
		}
	}
	return surfletSum;
}

float noise( vec3 p ) {
    return fract(sin(dot(p, vec3(127.1, 311.7, 631.2))) * 43758.5453);
} 

float interpNoise3D(vec3 p) {
    int intPX = int(floor(p.x));
    int intPY = int(floor(p.y));
    int intPZ = int(floor(p.z));

    vec3 fractP = fract(p);

    vec4 vz = vec4(noise(vec3(intPX, intPY, intPZ)),
                    noise(vec3(intPX + 1, intPY, intPZ)),
                    noise(vec3(intPX, intPY + 1, intPZ)), 
                    noise(vec3(intPX + 1, intPY + 1, intPZ)));

    vec4 vz_1 = vec4(noise(vec3(intPX, intPY, intPZ + 1)),
                    noise(vec3(intPX + 1, intPY, intPZ + 1)),
                    noise(vec3(intPX, intPY + 1, intPZ + 1)), 
                    noise(vec3(intPX + 1, intPY + 1, intPZ + 1)));

    float x1 = mix(vz.x, vz.y, fractP.x);
    float x2 = mix(vz.z, vz.w, fractP.x);
    float x3 = mix(vz_1.x, vz_1.y, fractP.x);
    float x4 = mix(vz_1.z, vz_1.w, fractP.x);
    
    float y1 = mix(x1, x2, fractP.y);
    float y2 = mix(x3, x4, fractP.y);
    
    return mix(y1, y2, fractP.z);

    
}

float fbm(vec3 pos) {
    float total = 0.f;
    float persistence = 0.5f;
    int octaves = 8;
    float freq = 3.f;
    float amp = 0.5f;
    for (int i = 1; i <= octaves; i++) {
        total += interpNoise3D(pos * freq + u_Time * 0.008) * amp;
        freq *= 2.f;
        amp *= persistence;
    }
    return total;
}

float map(float value, float min1, float max1, float min2, float max2) {
  return min2 + (value - min1) * (max2 - min2) / (max1 - min1);
}

float getBias(float time, float bias)
{
  return (time / ((((1.0/bias) - 2.0)*(1.0 - time))+1.0));
}

void main()
{
    // Material base color (before shading)
        vec4 diffuseColor = u_Color;

        // Calculate the diffuse term for Lambert shading
        float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
        // Avoid negative lighting values
        // diffuseTerm = clamp(diffuseTerm, 0, 1);

        float ambientTerm = 0.4;

        float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                            //to simulate ambient lighting. This ensures that faces that are not
                                                            //lit by our point light are not completely black.

        // Compute final shaded color
        vec3 color_inside = u_Color.xyz;
        vec3 color_outside = u_Color2.xyz;
        vec3 color_center = vec3(1.0, 1.0, 0.5);

        float fire_layer1 = 1. - map(acos(dot(vec3(0.0, 1.0, 0.0), fs_Nor.xyz)), radians(20.0), radians(135.0), 0.0, 1.0);

        float fire_layer2 = map(diffuseTerm, 0.6, 1.0, 0.0, 1.0) * max(0.8, perlinNoise3D(fs_Pos.xyz + u_Time * 0.008));
        vec3 color_layer2 = mix(color_outside, color_inside, fire_layer1 * fire_layer2);

        float fire_layer3 = 1. - fire_layer1;
        vec3 color_layer3 = color_inside * fire_layer3;

        float fire_layer4 = map(diffuseTerm, 0.85, 1.0, 0.0, 1.0);
        vec3 color_layer4 = mix(color_layer2 + color_layer3, color_center, clamp(fire_layer4, 0.0, 1.0) * max(0.2, min(fbm(fs_Pos.xyz), 1.0)));

        diffuseColor.rgb = color_layer4;


        out_Col = vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);
        // out_Col = vec4(color_layer2, 1.0);
}
