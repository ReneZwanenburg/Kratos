#version 330
uniform sampler2D texture;
in vec2 _texCoord;

void main()
{
	gl_FragData[0] = texture2D(texture, _texCoord);
}