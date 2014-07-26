module kratos.component.meshrenderer;

import kratos.entity;
import kratos.graphics.mesh;
import kratos.graphics.shader;
import kratos.graphics.vao;
import kratos.component.transform;

final class MeshRenderer : Component
{
	private Mesh	_mesh;
	private Shader	_shader;
	private VAO		_vao;

	@dependency
	private Transform _transform;

	this(Mesh mesh, Shader shader)
	{
		this._mesh = mesh;
		this._shader = shader;
		_vao = vao(mesh, shader.program);
	}

	@property
	{
		void mesh(Mesh mesh)
		{
			updateVao(mesh, _shader);
			this._mesh = mesh;
		}

		void shader(Shader shader)
		{
			updateVao(_mesh, shader);
			this._shader = shader;
		}

		ref Shader shader()
		{
			return _shader;
		}
	}

	private void updateVao(Mesh mesh, Shader shader)
	{
		if
		(	
			mesh.vertexAttributes		!= this._mesh.vertexAttributes || 
			shader.program.attributes	!= this._shader.program.attributes
		)
		{
			_vao = vao(mesh, shader.program);
		}
	}

	void draw()
	{
		_shader.prepare();
		_vao.bind();
		import kratos.graphics.gl;
		gl.DrawElements(GL_TRIANGLES, _mesh.ibo.byteLength / GLuint.sizeof, GL_UNSIGNED_INT, null);
	}
}