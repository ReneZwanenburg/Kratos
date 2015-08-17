#version 330

in vec2 normalizedCoord;

uniform sampler2D albedo;
uniform sampler2D normal;
uniform sampler2D depth;

uniform vec3 color;
uniform vec3 viewSpaceDirection;
uniform vec3 ambientColor;

out vec4 outputColor;

void main()
{
	vec3 sampleAlbedo = texture2D(albedo, normalizedCoord).rgb;
	vec3 sampleNormal = texture2D(normal, normalizedCoord).xyz;
	vec3 decodedNormal = sampleNormal * 2 - 1;
	
	vec3 result =
		sampleAlbedo * ambientColor +
		sampleAlbedo * color * dot(-viewSpaceDirection, decodedNormal);
	
	outputColor = vec4(result, 1);
}