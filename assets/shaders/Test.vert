#version 330
in vec3 position;
in vec2 texCoord;

uniform float scale;

out vec2 _texCoord;

void main()
{
	gl_Position = vec4(position * scale, 1);
	_texCoord = texCoord;
}