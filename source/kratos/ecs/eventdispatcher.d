module kratos.ecs.eventdispatcher;

import std.container.array : Array;

import std.traits : hasMember;
import std.algorithm.searching : canFind, find;
import std.range : only, take;

public final class RootDispatcher
{
	private alias FrameUpdater = void delegate();
	private Array!FrameUpdater frameUpdaters;

	private Object[TypeInfo_Class] dispatchers;

	public void frameUpdate()
	{
		foreach(frameUpdater; frameUpdaters)
		{
			frameUpdater();
		}
	}

	public auto getDispatcher(ComponentType)()
	{
		auto typeInfo = typeid(ComponentDispatcher!ComponentType);
		if(auto dispatcher = typeInfo in dispatchers)
		{
			return cast(ComponentDispatcher!ComponentType)*dispatcher;
		}
		else
		{
			auto dispatcher = new ComponentDispatcher!ComponentType(this);
			dispatchers[typeInfo] = dispatcher;
			return dispatcher;
		}
	}
}

package final class ComponentDispatcher(ComponentType)
{
	private Array!ComponentType components;

	this(RootDispatcher rootDispatcher)
	{
		static if(hasMember!(typeof(this), "frameUpdate"))
		{
			rootDispatcher.frameUpdaters.insertBack(&frameUpdate);
		}
	}

	package void add(ComponentType component)
	{
		components.insertBack(component);
		component.onDestruction += &componentDestructionEventHandler;
	}

	private void componentDestructionEventHandler(ComponentType.ComponentBaseType component)
	{
		auto rangeToRemove = components[].find(component).take(0);
		components.linearRemove(rangeToRemove);
	}

	static if(only(__traits(derivedMembers, ComponentType)).canFind("frameUpdate"))
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