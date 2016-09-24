#version 330

in vec2 normalizedCoord;
in vec2 projectionspaceCoord;

uniform sampler2D albedo;
uniform sampler2D normal;
uniform sampler2D depth;

uniform vec3 color;
uniform vec3 viewspaceDirection;
uniform vec3 ambientColor;

uniform mat4 projectionMatrixInverse;

out vec4 outputColor;

void main()
{
	vec4 sampleAlbedo = texture2D(albedo, normalizedCoord);
	vec4 sampleNormal = texture2D(normal, normalizedCoord);
	float sampleDepth = texture2D(depth, normalizedCoord).x;
	
	vec3 decodedAlbedo = sampleAlbedo.rgb;
	vec3 decodedNormal = sampleNormal.xyz * 2 - 1;
	float decodedSpecularLevel = sampleAlbedo.a;
	float decodedSpecularPower = max(0.001, sampleNormal.a * 128);
	vec4 unprojectedPosition = projectionMatrixInverse * vec4(projectionspaceCoord, sampleDepth, 1);
	vec3 viewspacePosition = unprojectedPosition.xyz / unprojectedPosition.w;
	
	float diffuseLevel = clamp(dot(-viewspaceDirection, decodedNormal), 0, 1);
	vec3 reflectionVector = reflect(viewspaceDirection, decodedNormal);
	float specularLevel = pow(clamp(dot(reflectionVector, -normalize(viewspacePosition)), 0, 1), decodedSpecularPower) * decodedSpecularLevel;
	
	vec3 result =
		decodedAlbedo * ambientColor +			// Ambient
		decodedAlbedo * color * diffuseLevel +	// Diffuse;
		color * specularLevel;					// Specular highlight
	
	outputColor = vec4(result, 1);
}