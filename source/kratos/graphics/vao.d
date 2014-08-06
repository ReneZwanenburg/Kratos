module kratos.graphics.vao;

import kratos.resource.resource;
import kratos.graphics.gl;
import kratos.graphics.shader;
import kratos.graphics.mesh;
import kratos.graphics.shadervariable;

import std.conv : to;
import std.logger;


alias VAO = Handle!VAO_Impl;

VAO vao(const Mesh mesh, const Program program)
{
	auto vao = initialized!VAO;
	gl.GenVertexArrays(1, &vao.handle);
	info("Created VAO ", vao.handle);
	tracef("Created VAO for IBO, VBO, Program attribs:\n%s\n%s\n%s", mesh.ibo, mesh.vbo, program.attributes);

	vao.bind();
	mesh.ibo.bind();
	mesh.vbo.bind();

	const stride = mesh.vbo.attributes.totalByteSize;
	
	foreach(programIndex, programAttribute; program.attributes)
	{
		import std.algorithm : countUntil;
		
		const vboIndex = mesh.vbo.attributes[].countUntil!q{a.name == b.name}(programAttribute);
		fatalc(vboIndex < 0, "VBO does not contain variable '", programAttribute.name, "': ", mesh.vbo.attributes.text);
		const vboAttribute = mesh.vbo.attributes[vboIndex];

		auto offset = mesh.vbo.attributes[0..vboIndex].totalByteSize;

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

void* offsetToVoidPtr(GLsizei offset)
{
	return cast(void*) offset;
}

private struct VAO_Impl
{
	private GLuint handle;
	
	@disable this(this);

	~this()
	{
		gl.DeleteVertexArrays(1, &handle);
		info("Deleted Vertex Array Object ", handle);
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
			trace("Binding VAO ", handle);
			gl.BindVertexArray(handle);
			current = handle;
		}
	}

	package static void unbind()
	{
		bind(0);
	}
}