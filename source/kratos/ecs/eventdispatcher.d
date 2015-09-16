module kratos.ecs.eventdispatcher;

import std.container.array : Array;

import std.traits : hasMember;
import std.algorithm.searching : canFind, find;
import std.range : only, take;

public final class RootDispatcher
{
	private ComponentDispatcherBase[] dispatchers;

	private alias FrameUpdater = void delegate();
	private FrameUpdater[] frameUpdaters;

	private bool requiresSort;

	public void frameUpdate()
	{
		ensureSorted();

		foreach(frameUpdater; frameUpdaters)
		{
			frameUpdater();
		}
	}

	package auto getDispatcher(ComponentType)()
	{
		auto typeInfo = typeid(ComponentType);
		auto result = dispatchers.find!(a => a.componentType is typeInfo);

		if(result.length > 0)
		{
			return cast(ComponentDispatcher!ComponentType)result[0];
		}
		else
		{
			auto dispatcher = new ComponentDispatcher!ComponentType();
			dispatchers ~= dispatcher;
			requiresSort = true;
			return dispatcher;
		}
	}

	private void ensureSorted()
	{
		if(!requiresSort) return;
		requiresSort = false;

		import std.algorithm.sorting : sort;

		dispatchers.sort!((a, b) => a.priority < b.priority);
		foreach(dispatcher; dispatchers) dispatcher.registerOptionals(this);
	}
}

private abstract class ComponentDispatcherBase
{
	public abstract void registerOptionals(RootDispatcher rootDispatcher);
	public @property int priority() const;
	public @priority TypeInfo_Class componentType() const;
}

package final class ComponentDispatcher(ComponentType) : ComponentDispatcherBase
{
	private enum derivedMembers = only(__traits(derivedMembers, ComponentType));
	private enum hasFrameUpdate = derivedMembers.canFind("frameUpdate");

	private Array!ComponentType components;
	private int _priority;

	private this()
	{
		import kratos.ecs.component : getComponentOrdering;
		_priority = getComponentOrdering()[componentType];
	}

	public override void registerOptionals(RootDispatcher rootDispatcher)
	{
		static if(hasFrameUpdate)
		{
			rootDispatcher.frameUpdaters ~= &frameUpdate;
		}
	}

	public override @property int priority() const
	{
		return _priority;
	}

	public override @property TypeInfo_Class componentType() const
	{
		return typeid(ComponentType);
	}

	package void add(ComponentType component)
	{
		components.insertBack(component);
		component.onDestruction += &componentDestructionEventHandler;
	}

	private void componentDestructionEventHandler(ComponentType.ComponentBaseType component)
	{
		auto rangeToRemove = components[].find(component).take(1);
		components.linearRemove(rangeToRemove);
	}

	static if(hasFrameUpdate)
	{
		void frameUpdate()
		{
			foreach(component; components[])
			{
				component.frameUpdate();
			}
		}
	}
}