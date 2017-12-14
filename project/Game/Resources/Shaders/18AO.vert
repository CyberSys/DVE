#version 330 core

// Input vertex data, different for all executions of this shader.
	layout(location = 0) in vec3 position;
	layout(location = 1) in vec3 TexCoordIn;
	layout(location = 2) in float lightLevel;

// Values that stay constant for the whole mesh
	uniform mat4 Model;
	uniform mat4 View;
	uniform mat4 Projection;

// Output data ; will be interpolated for each fragment.
	out vec3 TexCoord;
	out float LightLevel;


void main()
{
	gl_Position = Projection * View * Model * vec4(position, 1.0);	
    TexCoord = vec3(TexCoordIn.x, 1.0 - TexCoordIn.y, TexCoordIn.z);
    LightLevel = lightLevel;
}

