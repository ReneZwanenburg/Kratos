#version 330

in vec2 texCoord;

uniform sampler2D diffuseTexture;
uniform vec3 ambientColor;
uniform vec4 diffuseColor;
uniform vec3 specularColor;
uniform vec3 emissiveColor;

void main()
{
	gl_FragData[0] = texture2D(texture0, texCoord);
}