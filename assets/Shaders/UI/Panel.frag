#version 330

in vec2 texCoord;
out vec4 backBuffer;
uniform sampler2D texture;

void main()
{
	backBuffer = texture2D(texture, texCoord);
}