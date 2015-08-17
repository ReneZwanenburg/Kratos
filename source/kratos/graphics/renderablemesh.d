module kratos.graphics.renderablemesh;

import kratos.graphics.mesh;
import kratos.graphics.renderstate;
import kratos.graphics.vao;

auto renderableMesh()(Mesh mesh, auto ref RenderState renderState)
{
	return RenderableMesh(mesh, renderState);
}

struct RenderableMesh
{
	private Mesh		_mesh;
	private RenderState	_renderState;
	private VAO			_vao;

	@disable this();

	private this(Mesh mesh, ref RenderState renderState)
	{
		_mesh = mesh;
		_renderState = renderState;
		_vao = .vao(_mesh, _renderState.shader.program);
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
	}
}