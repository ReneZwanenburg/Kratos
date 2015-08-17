#version 330

in vec2 normalizedCoord;

uniform sampler2D albedo;
uniform sampler2D normal;
uniform sampler2D depth;

uniform vec3 color;
uniform vec3 projectionSpaceDirection;
uniform vec3 ambientColor;

out vec4 outputColor;

void main()
{
	outputColor = texture2D(albedo, normalizedCoord);
}