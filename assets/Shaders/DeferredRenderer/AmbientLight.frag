#version 330

in vec2 texCoord;

uniform sampler2D albedo;
uniform sampler2D normal;
uniform sampler2D depth;

uniform vec3 lighting;

out vec4 color;

void main()
{
	color = texture2D(albedo, texCoord) * vec4(lighting, 1);
}