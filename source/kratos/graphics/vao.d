module kratos.graphics.vao;

import kratos.resource.resource;
import kratos.graphics.gl;
import kratos.graphics.shader;
import kratos.graphics.mesh;
import kratos.graphics.shadervariable;

import std.conv : to;
import std.stdio : writeln; // TODO replace writeln with proper logging. Waiting for std.log


alias VAO = Handle!VAO_Impl;

VAO vao(const Mesh mesh, const Program program)
{
	auto vao = initialized!VAO;
	gl.GenVertexArrays(1, &vao.handle);
	debug writeln("Created Vertex Array Object ", vao.handle);

	vao.bind();
	mesh.ibo.bind();
	mesh.vbo.bind();

	const stride = mesh.vertexAttributes.totalByteSize;
	
	foreach(programIndex, programVariable; program.attributes)
	{
		import std.algorithm : countUntil;
		
		const vboIndex = mesh.vertexAttributes.countUntil!q{a.name == b.name}(programVariable);
		assert(vboIndex >= 0, "VBO does not contain variable '" ~ programVariable.name ~ "': " ~ mesh.vertexAttributes.text);
		const vboVariable = mesh.vertexAttributes[vboIndex];
		
		gl.EnableVertexAttribArray(programIndex);
		gl.VertexAttribPointer(
			programIndex,
			vboVariable.backingTypeSize,
			vboVariable.backingType,
			false,
			stride,
			cast(GLvoid*)mesh.vertexAttributes[0..vboIndex].totalByteSize
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
		debug writeln("Deleted Vertex Array Object ", handle);
	}
	
	void bind() const
	{
		gl.BindVertexArray(handle);
	}
}