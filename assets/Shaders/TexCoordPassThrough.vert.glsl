#version 330

in vec3 position;
in vec2 texCoord0;

out vec2 texCoord;

uniform mat4 WVP;

void main()
{
	gl_Position = WVP * vec4(position, 1);
	texCoord = texCoord0;
}