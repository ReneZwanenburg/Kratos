#version 330

in vec2 texCoord;

uniform sampler2D diffuseTexture;
uniform sampler2D specularTexture;
uniform sampler2D emissiveTexture;

uniform vec4 diffuseColor;
uniform vec4 specularColor;
uniform vec3 emissiveColor;

layout(location = 0) out vec4 albedo;
layout(location = 1) out vec4 normal;

void main()
{
	vec4 diffuseSample = texture2D(diffuseTexture, texCoord);
	
	albedo = diffuseSample * diffuseColor;
}