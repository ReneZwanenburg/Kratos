#version 330

in vec2 position;
in vec2 texCoord0;

out vec2 normalizedCoord;
out vec2 projectionspaceCoord;

void main()
{
	normalizedCoord = texCoord0;
	projectionspaceCoord = position;
	gl_Position = vec4(position, 0, 1);
}