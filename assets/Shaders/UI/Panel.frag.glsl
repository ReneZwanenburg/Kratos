#version 330

in vec2 texCoord;
out vec4 backBuffer;

uniform sampler2D texture;
uniform vec4 color;

void main()
{
	backBuffer = texture2D(texture, texCoord) * color;
}