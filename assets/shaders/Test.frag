#version 330

uniform sampler2D texture;

in vec3 viewSpaceNormal;
in vec2 texCoord;

layout(location = 0) out vec4 albedo;
layout(location = 1) out vec4 normal;

void main()
{
	albedo = texture2D(texture, texCoord);
	normal = vec4(viewSpaceNormal * 0.5 + 0.5, 1);
}