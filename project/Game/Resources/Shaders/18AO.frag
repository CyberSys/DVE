#version 330 core

// Interpolated values from the vertex shaders
	in vec3 TexCoord;
	in float LightLevel;

// Values that stay constant for the whole mesh
	uniform sampler2DArray TextureArray0;

// Ouput data
	out vec4 FragmentColour;

void main()
{
	float Texlayer=max(0,min(5-1,floor(TexCoord.z+0.5)));
//	FragmentColour = texture(TextureArray0, vec3(TexCoord.x, TexCoord.y, Texlayer)) * vec4(LightLevel, LightLevel, LightLevel, LightLevel);
	FragmentColour = texture(TextureArray0, vec3(TexCoord.x, TexCoord.y, Texlayer)) * LightLevel;	
}




