module kratos.component.meshrenderer;

import kratos.ecs.component : dependency;
import kratos.ecs.entity : Component;

import kratos.component.transform : Transform;
import kratos.component.spatialpartitioning : SpatialPartitioning;

import kratos.graphics.renderablemesh : RenderableMesh, renderableMesh;


alias MeshRendererPartitioning = SpatialPartitioning!MeshRenderer;

final class MeshRenderer : Component
{
	private @dependency Transform _transform;
	private RenderableMesh _mesh;

	this()
	{
		import kratos.graphics.mesh : Mesh;
		import kratos.graphics.renderstate : RenderState;

		this(renderableMesh(Mesh.init, RenderState.init));
	}

	this(RenderableMesh mesh)
	{
		_mesh = mesh;
		scene.components.firstOrAdd!MeshRendererPartitioning().register(this);
	}

	~this()
	{
		scene.components.first!MeshRendererPartitioning().deregister(this);
	}

	@property
	{
		// Should be package(kratos)
		Transform transform()
		{
			return _transform;
		}

		ref RenderableMesh mesh()
		{
			return _mesh;
		}

		void mesh(RenderableMesh mesh)
		{
			_mesh = mesh;
		}
	}

	string[string] toRepresentation()
	{
		return [
			"mesh": _mesh.mesh.id,
			"renderState": _mesh.renderState.id
		];
	}

	static MeshRenderer fromRepresentation(string[string] representation)
	{
		import kratos.resource.loader;
		return new MeshRenderer(
			renderableMesh(
				MeshCache.get(representation["mesh"]),
				RenderStateCache.get(representation["renderState"])));
	}
}