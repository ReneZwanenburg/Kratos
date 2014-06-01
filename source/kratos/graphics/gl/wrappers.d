module kratos.graphics.gl.wrappers;

import kratos.graphics.gl.gl;

struct VAO
{
	GLuint vertexArrayID;
	alias vertexArrayID this;
	
	static opCall()
	{
		VAO vao;
		gl.GenVertexArrays(1, &vao.vertexArrayID);
		return vao;
	}

	~this()
	{
		gl.DeleteVertexArrays(1, &vertexArrayID);
	}
}

void bind(VAO vao)
{
	gl.BindVertexArray(vao);
}