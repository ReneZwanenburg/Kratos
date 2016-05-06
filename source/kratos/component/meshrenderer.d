module kratos.component.meshrenderer;

import kratos.ecs.component : dependency;
import kratos.ecs.entity : Component;

import kratos.component.transform : Transform;
import kratos.component.spatialpartitioning : SpatialPartitioning;

import kratos.graphics.renderablemesh : RenderableMesh, renderableMesh;

import kgl3n.aabb : AABB;

alias MeshRendererPartitioning = SpatialPartitioning!MeshRenderer;

final class MeshRenderer : Component
{
	private @dependency Transform _transform;
	private RenderableMesh _mesh;
	private AABB _worldSpaceBound;

	Transform.ChangedRegistration worldtransformChangedRegistration;

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

	this(string meshFileName, string renderStateFileName)
	{
		import kratos.resource.loader.meshloader;
		import kratos.resource.loader.renderstateloader;
		
		this(renderableMesh
		(
			MeshLoader.get(meshFileName),
			RenderStateLoader.get(renderStateFileName)
		));
	}

	~this()
	{
		scene.components.first!MeshRendererPartitioning().deregister(this);
	}

	void initialize()
	{
		worldtransformChangedRegistration = transform.onWorldTransformChanged.register(&worldTransformChanged);
		worldTransformChanged(transform);
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
		
		AABB worldSpaceBound() const
		{
			return _worldSpaceBound;
		}
	}

	private void worldTransformChanged(Transform transform)
	{
		assert(transform is _transform);
		_worldSpaceBound = _mesh.modelSpaceBound.transformed(transform.worldMatrix);
	}

	string[string] toRepresentation()
	{
		import kratos.graphics.mesh : MeshManager;
	
		return [
			"mesh": MeshManager.getConcreteResource(mesh.mesh).name,
			"renderState": mesh.renderState.name
		];
	}

	static MeshRenderer fromRepresentation(string[string] representation)
	{
		return new MeshRenderer(representation["mesh"], representation["renderState"]);
	}
}