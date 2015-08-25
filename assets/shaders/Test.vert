#version 330

in vec3 position;
in vec3 normal;
in vec2 texCoord0;

uniform mat4 WVP;
uniform mat4 WV;

out vec3 viewspaceNormal;
out vec2 texCoord;

void main()
{
	gl_Position = WVP * vec4(position, 1);
	texCoord = texCoord0;
	viewspaceNormal = mat3(WV) * normal;
}