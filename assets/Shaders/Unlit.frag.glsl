#version 330

uniform sampler2D texture;
uniform vec4 color;

in vec2 texCoord;

out vec4 fragColor;

void main()
{
	fragColor = texture2D(texture, texCoord) * color;
}