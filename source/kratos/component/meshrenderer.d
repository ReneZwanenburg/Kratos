module kratos.component.meshrenderer;

import kratos.ecs;
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

	private @dependency Transform _transform;

	alias renderState this;

	this()
	{
		this(emptyMesh, defaultRenderState);
	}

	this(Mesh mesh, RenderState renderState)
	{
		this._mesh = mesh;
		this._renderState = renderState;
		//TODO: Hack to support scene creation without GL context, fix nicely.
		if(_mesh.vbo.refCountedStore.isInitialized)
		{
			_vao = .vao(_mesh, _renderState.shader.program);
		}

		scene.components.firstOrAdd!MeshRendererPartitioning().register(this);
	}

	~this()
	{
		scene.components.first!MeshRendererPartitioning().deregister(this);
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

		void shader()(auto ref Shader shader)
		{
			updateVao(_mesh, shader.program);
			renderState.shader = shader;
		}

		ref Shader shader()
		{
			return renderState.shader;
		}

		Mesh mesh()
		{
			return _mesh;
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

		package ref VAO vao()
		{
			return _vao;
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
			_vao = .vao(mesh, program);
		}
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
		return [
			"mesh": _mesh.id,
			"renderState": _renderState.id
		];
	}

	static MeshRenderer fromRepresentation(string[string] representation)
	{
		import kratos.resource.loader;
		return new MeshRenderer(
			MeshCache.get(representation["mesh"]),
			RenderStateCache.get(representation["renderState"]));
	}
}


final class MeshRendererPartitioning : SceneComponent
{
	import std.container : Array;
	private MeshRenderer[] _meshRenderers;

	public auto all()
	{
		return _meshRenderers[];
	}

	private void register(MeshRenderer mesh)
	{
		_meshRenderers ~= mesh;
	}

	private void deregister(MeshRenderer mesh)
	{
		import std.algorithm.searching : countUntil;
		import std.algorithm.mutation : remove, SwapStrategy;

		_meshRenderers = _meshRenderers.remove!(SwapStrategy.unstable)(_meshRenderers.countUntil(mesh));
		_meshRenderers.assumeSafeAppend();
	}
}