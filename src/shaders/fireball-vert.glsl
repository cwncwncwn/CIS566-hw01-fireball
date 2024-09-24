#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself
uniform float u_Time;
uniform vec3 u_CamPos;

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Pos;
out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.

const vec4 lightPos = vec4(0, 0, 5, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

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
                vec3 pos = p * 1.2 - u_Time * 0.008;
                // vec3 pos = p;
				surfletSum += surflet(pos, floor(pos) + vec3(dx, dy, dz));
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



void main()
{
    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation

    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.

    fs_Pos = vs_Pos;

    float perlin = perlinNoise3D(vs_Pos.xyz);
    vec3 offset_low_freq = normalize(vs_Nor.xyz * vec3(0.1, 1.0, 0.1)) * perlin;
    vec3 offset_high_freq = normalize(vs_Nor.xyz) * fbm(vs_Pos.xyz * 0.6);

    float flame_mask = 1. - smoothstep(0.0, 1.0, map(acos(dot(vec3(0.0, 1.0, 0.0), fs_Nor.xyz)), radians(20.0), radians(80.0), 0.0, 1.0));
    float flame_mask_2 = 1. - smoothstep(0.0, 1.0, map(acos(dot(vec3(0.0, 1.0, 0.0), fs_Nor.xyz)), radians(20.0), radians(180.0), 0.0, 1.0));
    
    vec4 modelposition = u_Model * vs_Pos  + 
                        vec4(offset_low_freq + vec3(0.0, 0.8, 0.0), 0.f) * flame_mask * 1.5 - 
                        vec4(offset_low_freq, 0.0) * 0.1 * (sin(u_Time * 0.01) * 1.3 + 1.2) + 
                        vec4(offset_high_freq, 0.f) * 0.5 * flame_mask_2;

    fs_LightVec = vec4(u_CamPos, 1.0) - modelposition;  // Compute the direction in which the light source lies

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
