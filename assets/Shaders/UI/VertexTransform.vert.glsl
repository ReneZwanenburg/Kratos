#version 330

uniform mat4 W;

in vec2 position;
in vec2 texCoord0;

out vec2 texCoord;

void main()
{
	texCoord = texCoord0;
	gl_Position = W * vec4(position, 0, 1);
}