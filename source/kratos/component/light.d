module kratos.component.light;

import kratos.ecs.component : dependency, ignore;
import kratos.ecs.entity : Component;

import kratos.component.transform : Transform;
import kratos.component.spatialpartitioning : SpatialPartitioning;

import kgl3n.vector : vec3;


alias DirectionalLightPartitioning = SpatialPartitioning!DirectionalLight;

public final class DirectionalLight : Component
{
	this()
	{
		scene.components.firstOrAdd!DirectionalLightPartitioning().register(this);
	}

	~this()
	{
		scene.components.first!DirectionalLightPartitioning().deregister(this);
	}

	vec3 color;
	vec3 ambientColor;
	vec3 direction;
}


alias PointLightPartitioning = SpatialPartitioning!PointLight;

public final class PointLight : Component
{
	@dependency
	private Transform transform;

	private vec3 color;
	private float range;
}