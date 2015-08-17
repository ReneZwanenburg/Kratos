#version 330

uniform sampler2D texture;

in vec3 projectionSpaceNormal;
in vec2 texCoord;

layout(location = 0) out vec4 albedo;
layout(location = 1) out vec4 normal;

void main()
{
	albedo = texture2D(texture, texCoord);
	normal = vec4(projectionSpaceNormal * 0.5 + 0.5, 1);
}