#version 330

in vec2 normalizedCoord;
in vec2 projectionspaceCoord;

uniform sampler2D albedo;
uniform sampler2D normal;

uniform vec3 ambientColor;

out vec4 outputColor;

void main()
{
	vec4		sampleAlbedo	= texture2D(albedo, normalizedCoord);
	vec4		sampleNormal	= texture2D(normal, normalizedCoord);
	
	vec3		unpackedAlbedo		= sampleAlbedo.rgb;
	float	unpackedDiffuseLevel	= sampleAlbedo.a;
	float	unpackedEmissiveLevel	= sampleNormal.a * 1024;
	
	vec3 result =
		unpackedAlbedo * ambientColor * unpackedDiffuseLevel +	// Ambient
		unpackedAlbedo * unpackedEmissiveLevel;				// Emissive;
	
	outputColor = vec4(result, 1);
}