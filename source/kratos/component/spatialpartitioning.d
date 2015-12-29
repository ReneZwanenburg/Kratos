module kratos.component.spatialpartitioning;

import kratos.ecs.scene : SceneComponent;
import kgl3n.frustum : Frustum;
import std.algorithm.iteration : filter;

public final class SpatialPartitioning(ComponentType) : SceneComponent
{
	enum hasBounds = is(typeof(ComponentType.init.worldSpaceBound));
	
	private ComponentType[] _components;
	
	auto all()
	{
		return _components[];
	}
	
	static if(hasBounds)
	{
		auto intersecting(Frustum frustum)
		{
			return all.filter!(a => frustum.intersects(a.worldSpaceBound));
		}
	}
	
	void register(ComponentType component)
	{
		_components ~= component;
	}
	
	void deregister(ComponentType component)
	{
		import std.algorithm.searching : countUntil;
		import std.algorithm.mutation : remove, SwapStrategy;
		
		_components = _components.remove!(SwapStrategy.unstable)(_components.countUntil(component));
		_components.assumeSafeAppend();
	}
}