#version 330

in vec2 texCoord;

uniform sampler2D diffuseTexture;

void main()
{
	gl_FragData[0] = texture2D(texture0, texCoord);
}