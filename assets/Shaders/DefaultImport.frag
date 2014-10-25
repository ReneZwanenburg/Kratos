#version 330

in vec2 texCoord;

uniform sampler2D diffuseTexture;
uniform sampler2D specularTexture;
uniform sampler2D emissiveTexture;

uniform vec3 ambientColor;
uniform vec4 diffuseColor;
uniform vec4 specularColor;
uniform vec3 emissiveColor;

void main()
{
	vec4 diffuseSample = texture2D(diffuseTexture, texCoord);
	
	gl_FragData[0] = vec4(
		ambientColor.rgb * diffuseSample.rgb * 0.0001 +
		diffuseColor.rgb * diffuseSample.rgb +
		emissiveColor * texture2D(emissiveTexture, texCoord).rgb * 0.0001 + 
		specularColor.rgb * texture2D(specularTexture, texCoord).rgb * 0.0001,
		diffuseColor.a * diffuseSample.a
	);
}