#version 330

uniform sampler2D texture;
uniform vec4 color;

in vec2 texCoord;

void main()
{
	gl_FragData[0] = texture2D(texture, texCoord) * color;
}