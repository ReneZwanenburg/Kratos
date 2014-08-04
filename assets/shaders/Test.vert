#version 330
in vec3 position;
in vec2 texCoord;

uniform mat4 WVP;

out vec2 _texCoord;

void main()
{
	gl_Position = WVP * vec4(position, 1);
	_texCoord = texCoord;
}