#version 330

uniform sampler2D texture;

in vec3 viewspaceNormal;
in vec2 texCoord;

layout(location = 0) out vec4 albedo; // rgb = albedo, a = specular level
layout(location = 1) out vec4 normal; // rgb = viewspace normal xyz, a = specular power / 128

void main()
{
	vec3 albedoSample = texture2D(texture, texCoord).rgb;
	float specularLevel = dot(albedoSample, vec3(1)) * 0.75 + 0.25;
	
	albedo = vec4(albedoSample, specularLevel);
	normal = vec4(viewspaceNormal * 0.5 + 0.5, specularLevel);
}