#version 330

in vec2 normalizedCoord;
in vec2 projectionspaceCoord;

uniform sampler2D albedo;
uniform sampler2D normal;
uniform sampler2D surfaceParameters;
uniform sampler2D depth;

uniform vec3 color;
uniform vec3 viewspaceDirection;

uniform mat4 projectionMatrixInverse;

out vec4 outputColor;

void main()
{
	vec4		sampleAlbedo				= texture2D(albedo, normalizedCoord);
	vec4		sampleNormal				= texture2D(normal, normalizedCoord);
	vec2		sampleSurfaceParameters	= texture2D(surfaceParameters, normalizedCoord).rg;
	float	sampleDepth				= texture2D(depth, normalizedCoord).x;
	
	vec3		unpackedAlbedo		= sampleAlbedo.rgb;
	float	unpackedDiffuseLevel	= sampleAlbedo.a;
	vec3		unpackedNormal		= sampleNormal.xyz * 2 - 1;
	float	unpackedSpecularPower	= max(0.001, sampleSurfaceParameters.r * 128);
	float	unpackedSpecularLevel	= sampleSurfaceParameters.g;
	
	//TODO Don't use inverse projection if the camera uses a simple perspective projection
	vec4 unprojectedPosition	= projectionMatrixInverse * vec4(projectionspaceCoord, sampleDepth, 1);
	vec3 viewspacePosition		= unprojectedPosition.xyz / unprojectedPosition.w;
	
	float	diffuseLevel		= clamp(dot(-viewspaceDirection, unpackedNormal), 0, 1) * unpackedDiffuseLevel;
	vec3		reflectionVector	= reflect(viewspaceDirection, unpackedNormal);
	float	specularLevel		= pow(clamp(dot(reflectionVector, -normalize(viewspacePosition)), 0, 1), unpackedSpecularPower) * unpackedSpecularLevel;
	
	vec3 result =
		unpackedAlbedo * color * diffuseLevel +	// Diffuse;
		color * specularLevel;					// Specular highlight
	
	outputColor = vec4(result, 1);
}