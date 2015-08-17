#version 330
in vec3 position;
in vec3 normal;
in vec2 texCoord0;

uniform mat4 WVP;

out vec3 projectionSpaceNormal;
out vec2 texCoord;

void main()
{
	gl_Position = WVP * vec4(position, 1);
	texCoord = texCoord0;
	projectionSpaceNormal = mat3(WVP) * normal;
}