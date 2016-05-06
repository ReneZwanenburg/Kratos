module kratos.graphics.renderablemesh;

import kratos.graphics.mesh;
import kratos.graphics.renderstate;
import kratos.graphics.vao;
import kgl3n.aabb;

auto renderableMesh()(Mesh mesh, auto ref RenderState renderState)
{
	return RenderableMesh(mesh, renderState);
}

auto defaultRenderableMesh()
{
	return renderableMesh(emptyMesh, defaultRenderState);
}

struct RenderableMesh
{
	private Mesh		_mesh;
	private RenderState	_renderState;
	private VAO			_vao;
	private AABB		_modelSpaceBound;

	@disable this();

	private this(Mesh mesh, ref RenderState renderState)
	{
		_mesh = mesh;
		_renderState = renderState;
		_vao = .vao(_mesh, _renderState.shader.program);

		import kgl3n.vector : vec3;
		static struct Vertex { vec3 position; }
		
		auto meshImpl = MeshManager.getConcreteResource(_mesh);

		if(meshImpl.vbo.isValidCustomFormat!Vertex)
		{
			import std.algorithm.iteration : map;
			_modelSpaceBound = AABB.fromPoints(meshImpl.vbo.getCustom!Vertex.map!(a => a.position));
		}
	}

	@property
	{
		Mesh mesh()
		{
			return _mesh;
		}

		ref RenderState renderState()
		{
			return _renderState;
		}

		VAO vao()
		{
			return _vao;
		}

		AABB modelSpaceBound() const
		{
			return _modelSpaceBound;
		}
	}
}