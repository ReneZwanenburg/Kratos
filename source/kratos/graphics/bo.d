module kratos.graphics.bo;

import kratos.resource.resource;
import kratos.graphics.gl;

import std.stdio : writeln; // TODO replace writeln with proper logging. Waiting for std.log


alias VBO = BO!GL_ARRAY_BUFFER;
alias vbo = bo!GL_ARRAY_BUFFER;

alias IBO = BO!GL_ELEMENT_ARRAY_BUFFER;
alias ibo = bo!GL_ELEMENT_ARRAY_BUFFER;

private alias BO(GLenum Target) = Handle!(BO_Impl!Target);

private BO!Target bo(GLenum Target)()
{
	auto bo = initialized!(BO!Target);
	gl.GenBuffers(1, &bo.handle);
	debug writeln("Created Buffer Object ", bo.handle);
	return bo;
}

private struct BO_Impl(GLenum Target)
{
	private GLuint handle;
	
	@disable this(this);
	
	~this()
	{
		gl.DeleteBuffers(1, &handle);
		debug writeln("Deleted Buffer Object ", handle);
	}
	
	void bind()
	{
		gl.BindBuffer(Target, handle);
	}
}