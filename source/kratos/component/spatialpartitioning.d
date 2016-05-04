module kratos.component.spatialpartitioning;

import kratos.ecs.scene : SceneComponent;
import std.container.array : Array;

public final class SpatialPartitioning(ComponentType) : SceneComponent
{
	enum hasBounds = is(typeof(ComponentType.init.worldSpaceBound));
	
	private Array!ComponentType _components;
	
	auto all()
	{
		return _components[];
	}
	
	static if(hasBounds)
	{
		auto intersecting(T)(T shape)
		{
			// Looks a bit roundabout, but avoids allocating a closure.
			import std.algorithm.iteration : filter, map;
			import std.range : repeat, zip;
			import kgl3n.intersect : testIntersection;
			
			return 
				zip(all, repeat(shape))
				.filter!(a => testIntersection(a[1], a[0].worldSpaceBound))
				.map!(a => a[0]);
		}
	}
	
	void register(ComponentType component)
	{
		_components.insertBack(component);
	}
	
	void deregister(ComponentType component)
	{
		import kratos.util : linearRemove;
		
		// This potentially has terrible performance when all components are destructed in front to back order..
		linearRemove(_components, component);
	}
}