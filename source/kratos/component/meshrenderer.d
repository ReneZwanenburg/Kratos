module kratos.component.meshrenderer;

import kratos.entity;
import kratos.graphics.mesh;
import kratos.graphics.shader;
import kratos.graphics.vao;
import kratos.graphics.renderstate;
import kratos.component.transform;

final class MeshRenderer : Component
{
	private Mesh		_mesh;
	//TODO: Make Shader part of RenderState
	private RenderState	_renderState;
	private VAO			_vao;

	@Dependency()
	private Transform _transform;

	this()
	{
		this(emptyMesh, defaultShader);
	}

	this(Mesh mesh, Shader shader)
	{
		this._mesh = mesh;
		this.renderState.shader = shader;
		_vao = vao(mesh, shader.program);
	}

	@property
	{
		void mesh(Mesh mesh)
		{
			updateVao(mesh, shader.program);
			this._mesh = mesh;
		}

		void shader()(auto ref Shader shader)
		{
			updateVao(_mesh, shader.program);
			renderState.shader = shader;
		}

		ref Shader shader()
		{
			return renderState.shader;
		}

		ref RenderState renderState()
		{
			return _renderState;
		}

		void renderState(RenderState renderState)
		{
			this._renderState = renderState;
		}
	}

	private void updateVao(const Mesh mesh, const Program program)
	{
		if
		(	
			mesh.vertexAttributes		!= this._mesh.vertexAttributes || 
			program.attributes			!= this.shader.program.attributes
		)
		{
			_vao = vao(mesh, program);
		}
	}

	void draw()
	{
		_vao.bind();
		_renderState.apply();
		import kratos.graphics.gl;
		gl.DrawElements(GL_TRIANGLES, _mesh.ibo.byteLength / GLuint.sizeof, GL_UNSIGNED_INT, null);
	}

	private static ref Shader defaultShader()
	{
		static bool initialized = false;
		static Shader shader;
		
		if(!initialized)
		{
			shader = Shader(errorProgram);
			initialized = true;
		}
		return shader;
	}
}