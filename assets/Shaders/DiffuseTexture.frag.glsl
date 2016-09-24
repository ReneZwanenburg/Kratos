#version 330

layout(location = 0) out vec4 albedo;
layout(location = 1) out vec4 normal;

in vec3 viewNormal;
in vec2 texCoord;

uniform sampler2D texture;
uniform vec3 color;

void main()
{
	vec3 texSample = texture2D(texture, texCoord).rgb;
	albedo = vec4(color * texSample, 0.8);
	normal = vec4(viewNormal * 0.5 + 0.5, 0.5);
}