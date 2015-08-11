#version 330

uniform sampler2D texture;

in vec2 texCoord;

layout(location = 0) out vec4 color;
layout(location = 1) out vec4 normal;

void main()
{
	color = texture2D(texture, texCoord);
	normal = vec4(0);
}