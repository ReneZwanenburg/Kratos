#version 330

in vec3 position;
in vec3 normal;
in vec2 texCoord0;

out vec3 viewNormal;
out vec2 texCoord;

uniform mat4 WVP;
uniform mat4 WV;

void main()
{
	gl_Position = WVP * vec4(position, 1);
	viewNormal = mat3(WV) * normal;
	texCoord = texCoord0;
}