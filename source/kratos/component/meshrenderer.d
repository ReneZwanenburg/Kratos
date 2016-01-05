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
	private AABB _modelSpaceBoundingBox;

	this()
	{
		import kratos.graphics.mesh : Mesh;
		import kratos.graphics.renderstate : RenderState;

		this(renderableMesh(Mesh.init, RenderState.init));
	}

	this(RenderableMesh mesh)
	{
		_mesh = mesh;
		updateBound();
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
			updateBound();
		}
		
		AABB worldSpaceBound() const
		{
			return _modelSpaceBoundingBox.transformed(_transform.worldMatrix);
		}
	}
	
	private void updateBound()
	{
		import kgl3n.vector : vec3;
		import std.algorithm.iteration : map;
		// Duplicate work when re-using meshes. Should store it at a lower level.
		static struct Vertex
		{
			vec3 position;
		}

		_modelSpaceBoundingBox = AABB.fromPoints(mesh.mesh.vbo.getCustom!Vertex.map!(a => a.position));
	}

	string[string] toRepresentation()
	{
		return [
			"mesh": mesh.mesh.id,
			"renderState": mesh.renderState.id
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