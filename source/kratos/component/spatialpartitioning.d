module kratos.component.spatialpartitioning;

import kratos.ecs.scene : SceneComponent;
import kgl3n.frustum : Frustum;
import kgl3n.intersect : testIntersection;
import std.algorithm.iteration : filter, map;
import std.range : repeat, zip;

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
		auto intersecting(T)(T shape)
		{
			// Looks a bit roundabout, but avoids allocating a closure.
			return 
				zip(all, repeat(shape))
				.filter!(a => testIntersection(a[1], a[0].worldSpaceBound))
				.map!(a => a[0]);
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