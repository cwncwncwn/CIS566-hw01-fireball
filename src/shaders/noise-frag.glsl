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
uniform float u_Time;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them

in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.


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


void main()
{
    // Material base color (before shading)
        vec3 oppo_col = 1.f - u_Color.xyz;
        vec4 diffuseColor = vec4(mix( oppo_col, u_Color.xyz, fbm(fs_Pos.xyz)), u_Color.a);

        // Calculate the diffuse term for Lambert shading
        float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
        // Avoid negative lighting values
        // diffuseTerm = clamp(diffuseTerm, 0, 1);

        float ambientTerm = 1.;

        float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                            //to simulate ambient lighting. This ensures that faces that are not
                                                            //lit by our point light are not completely black.

        // Compute final shaded color
        out_Col = vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a);
}
