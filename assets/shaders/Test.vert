#version 330
in vec3 position;
in vec2 texCoord0;

uniform mat4 WVP;

out vec2 texCoord;

void main()
{
	gl_Position = WVP * vec4(position, 1);
	texCoord = texCoord0;
}