module kratos.graphics.shadervariable;

import kratos.graphics.gl;


struct ShaderVariable
{
	GLint				size; // Size in 'type' units, not byte size
	GLenum				type;
	immutable(GLchar)[]	name; // D-like string. No null terminator.
	
	@property GLsizei byteSize() const pure nothrow
	{
		return size * GLTypeSize[type];
	}
}

GLsizei totalByteSize(const ShaderVariable[] variables)
{
	import std.algorithm : reduce;
	return reduce!q{a + b.byteSize}(0, variables);
}