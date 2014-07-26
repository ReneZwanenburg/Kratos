﻿module kratos.graphics.bo;

import kratos.resource.resource;
import kratos.graphics.gl;

import std.logger;
import std.container : Array;


alias VBO = BO!GL_ARRAY_BUFFER;
alias vbo = bo!GL_ARRAY_BUFFER;

alias IBO = BO!GL_ELEMENT_ARRAY_BUFFER;
alias ibo = bo!GL_ELEMENT_ARRAY_BUFFER;

private alias BO(GLenum Target) = Handle!(BO_Impl!Target);

BO!Target bo(GLenum Target)(void[] data, bool dynamic = false)
{
	assert(!dynamic, "Dynamic Buffer Objects not yet supported");

	auto bo = BO!Target(data.length);
	gl.GenBuffers(1, &bo.handle);
	info("Created Buffer Object ", bo.handle);

	bo.bind();
	gl.BufferData(Target, data.length, data.ptr, dynamic ? GL_DYNAMIC_DRAW : GL_STATIC_DRAW);

	return bo;
}

private struct BO_Impl(GLenum Target)
{
	const	size_t	byteLength;
	private GLuint	handle;
	
	@disable this(this);

	~this()
	{
		gl.DeleteBuffers(1, &handle);
		info("Deleted Buffer Object ", handle);
	}
	
	void bind() const
	{
		trace("Binding Buffer Object ", handle);
		gl.BindBuffer(Target, handle);
	}
}