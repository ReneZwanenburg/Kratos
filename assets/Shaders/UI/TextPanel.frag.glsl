#version 330

in vec2 texCoord;
out vec4 backBuffer;

uniform sampler2D texture;
uniform vec3 color;

void main()
{
	float alpha = texture2D(texture, texCoord).r;
	//if(alpha == 0) discard;
	backBuffer = vec4(color, alpha);
}