﻿module kratos.graphics.vao;

import kratos.graphics.gl;
import kratos.graphics.shader;
import kratos.graphics.mesh;
import kratos.graphics.shadervariable;

import std.conv : to;
//import std.experimental.logger;
import kratos.resource.manager;


alias VAO = Handle!VAO_Impl;

VAO vao(Mesh mesh, Program program)
{
	auto vao = VAO.init;
	vao.refCountedStore.ensureInitialized();
	gl.GenVertexArrays(1, &vao.handle);
	//info("Created VAO ", vao.handle);
	//TODO: Remove manual toString calls once logger is fixed
	//tracef("VAO linking VBO, Program attribs:\n%s\n%s", mesh.vbo.attributes, program.attributes);
	//tracef("VAO linking VBO, Program attribs:\n%s\n%s", mesh.vbo.attributes.toString(), program.attributes.toString());

	auto meshImpl = MeshManager.getConcreteResource(mesh);
	
	vao.bind();
	meshImpl.ibo.bind();
	meshImpl.vbo.bind();

	const stride = meshImpl.vbo.attributes.totalByteSize;
	
	foreach(GLuint programIndex, programAttribute; ProgramManager.getConcreteResource(program).attributes)
	{
		import std.algorithm : countUntil;
		
		const vboIndex = meshImpl.vbo.attributes[].countUntil!q{a.name == b.name}(programAttribute);
		//fatal(vboIndex < 0, "VBO does not contain variable '", programAttribute.name[], "': ", meshImpl.vbo.attributes.text);
		const vboAttribute = meshImpl.vbo.attributes[vboIndex];

		auto offset = meshImpl.vbo.attributes[0..vboIndex].totalByteSize;

		gl.EnableVertexAttribArray(programIndex);
		gl.VertexAttribPointer(
			programIndex,
			vboAttribute.basicTypeSize,
			vboAttribute.basicType,
			false,
			stride,
			cast(void*)offset
		);
	}
	
	return vao;
}

private struct VAO_Impl
{
	private GLuint handle;
	
	@disable this(this);

	~this()
	{
		gl.DeleteVertexArrays(1, &handle);
		//info("Deleted Vertex Array Object ", handle);
	}

	void bind() const
	{
		bind(handle);
	}
	
	private static void bind(GLuint handle)
	{
		static GLuint current = 0;

		if(current != handle)
		{
			//trace("Binding VAO ", handle);
			gl.BindVertexArray(handle);
			current = handle;
		}
	}

	package static void unbind()
	{
		bind(0);
	}
}