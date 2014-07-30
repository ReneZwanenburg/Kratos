module kratos.graphics.textureunit;

import kratos.graphics.gl;

// This file, as well as the split between TextureUnit and TextureUnits is unneccessary except
// we need to break the not-really cyclic dependency between gl and texture module constructors

struct TextureUnit
{
	const GLint index;
	
	this(GLint index)
	{
		assert(0 <= index && index < Size);
		this.index = index;
	}

	enum Size = 48;
}