#version 330

in vec2 position;

out vec2 normalizedCoord;
out vec2 projectionspaceCoord;

void main()
{
	normalizedCoord = position * 0.5 + 0.5;
	projectionspaceCoord = position;
	gl_Position = vec4(position, 0, 1);
}