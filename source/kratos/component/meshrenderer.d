module kratos.component.meshrenderer;

import kratos.entity;
import kratos.graphics.mesh;
import kratos.graphics.shader;
import kratos.graphics.vao;
import kratos.graphics.renderstate;
import kratos.component.transform;
import vibe.data.serialization : ignore;

private alias registration = RegisterComponent!MeshRenderer;

final class MeshRenderer : Component
{
	private Mesh		_mesh;
	//TODO: Make Shader part of RenderState
	private RenderState	_renderState;
	private VAO			_vao;

	private @dependency Transform _transform;

	alias renderState this;

	this()
	{
		this(emptyMesh, defaultRenderState);
	}

	private this(Mesh mesh, RenderState renderState)
	{
		this._mesh = mesh;
		this._renderState = renderState;
		_vao = vao(_mesh, _renderState.shader.program);
	}

	void set(Mesh mesh, RenderState renderState)
	{
		updateVao(mesh, renderState.shader.program);
		this._mesh = mesh;
		this.renderState = renderState;
	}

	@property
	{
		void mesh(Mesh mesh)
		{
			updateVao(mesh, shader.program);
			this._mesh = mesh;
		}

		@ignore
		void shader()(auto ref Shader shader)
		{
			updateVao(_mesh, shader.program);
			renderState.shader = shader;
		}

		@ignore
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

		// Should be package(kratos)
		ref Transform transform()
		{
			return _transform;
		}
	}

	private void updateVao(const Mesh mesh, const Program program)
	{
		if
		(	
			mesh.vbo.attributes	!= this._mesh.vbo.attributes || 
			program.attributes	!= this.shader.program.attributes
		)
		{
			_vao = vao(mesh, program);
		}
	}

	void draw()
	{
		_vao.bind();
		shader.uniforms.updateBuiltins(this);
		_renderState.apply();
		import kratos.graphics.gl;
		gl.DrawElements(GL_TRIANGLES, _mesh.ibo.numIndices, _mesh.ibo.indexType, null);
	}

	private static ref RenderState defaultRenderState()
	{
		static bool initialized = false;
		static RenderState state;
		
		if(!initialized)
		{
			state.shader = Shader(errorProgram);
			initialized = true;
		}
		return state;
	}

	string[string] toRepresentation()
	{
		return null;
		//assert(false, "Not implemented yet");
	}

	static MeshRenderer fromRepresentation(string[string] representation)
	{
		import kratos.resource.loader;
		return new MeshRenderer(
			MeshCache.get(representation["mesh"]),
			RenderStateCache.get(representation["renderState"]));
	}
}