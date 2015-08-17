module kratos.component.spatialpartitioning;

import kratos.ecs.scene : SceneComponent;

public final class SpatialPartitioning(ComponentType) : SceneComponent
{
	private ComponentType[] _components;
	
	auto all()
	{
		return _components[];
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