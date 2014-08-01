#version 330
uniform sampler2D texture;
uniform vec3 color;
in vec2 _texCoord;

void main()
{
	gl_FragData[0] = texture2D(texture, _texCoord) * vec4(color, 1);
}