module kratos.ecs.eventdispatcher;

import std.container.array : Array;

import std.algorithm.searching : canFind, find;
import std.range : only;

public final class RootDispatcher
{
	private GenericComponentManager[] managers;

	private alias FrameUpdater = void delegate();
	private FrameUpdater[] frameUpdaters;

	private alias PhysicsPreStepUpdater = void delegate();
	private PhysicsPreStepUpdater[] physicsPreStepUpdaters;

	private alias PhysicsPostStepUpdater = void delegate();
	private PhysicsPostStepUpdater[] physicsPostStepUpdaters;

	private bool requiresSort;

	public void frameUpdate()
	{
		ensureSorted();

		foreach(frameUpdater; frameUpdaters)
		{
			frameUpdater();
		}
	}

	public void physicsPreStepUpdate()
	{
		ensureSorted();

		foreach(physicsPreStepUpdater; physicsPreStepUpdaters)
		{
			physicsPreStepUpdater();
		}
	}

	public void physicsPostStepUpdate()
	{
		ensureSorted();

		foreach(physicsPostStepUpdater; physicsPostStepUpdaters)
		{
			physicsPostStepUpdater();
		}
	}

	package auto getManager(ComponentType)()
	{
		auto typeInfo = typeid(ComponentType);
		auto result = managers.find!(a => a.componentType is typeInfo);

		if(result.length > 0)
		{
			return cast(ComponentManager!ComponentType)result[0];
		}
		else
		{
			auto manager = createManager!ComponentType;
			managers ~= manager;
			requiresSort = true;
			return manager;
		}
	}

	private auto createManager(ComponentType)()
	{
		enum derivedMembers = only(__traits(derivedMembers, ComponentType));
		static if(derivedMembers.canFind("ManagerType"))
		{
			static assert(is(ComponentType.ManagerType));
			return new ComponentType.ManagerType();
		}
		else
		{
			return new DefaultComponentManager!ComponentType();
		}
	}

	private void ensureSorted()
	{
		if(!requiresSort) return;
		requiresSort = false;
		
		frameUpdaters.length = 0;
		physicsPreStepUpdaters.length = 0;
		physicsPostStepUpdaters.length = 0;

		import std.algorithm.sorting : sort;

		managers.sort!((a, b) => a.priority < b.priority);
		foreach(manager; managers) manager.registerOptionals(this);
	}
}

private interface GenericComponentManager
{
	void registerOptionals(RootDispatcher rootDispatcher);
	@property int priority() const;
	@property TypeInfo_Class componentType() const;
}

public abstract class ComponentManager(ComponentType) : GenericComponentManager
{
	abstract void add(ComponentType component);

	final @property const
	{
		TypeInfo_Class componentType() { return typeid(ComponentType); }
		int priority() { return _priority; }
	}

	private int _priority;

	protected this()
	{
		import kratos.ecs.component : getComponentOrdering;
		_priority = getComponentOrdering()[componentType];
	}
}

private final class DefaultComponentManager(ComponentType) : ComponentManager!ComponentType
{
	private enum derivedMembers = only(__traits(derivedMembers, ComponentType));
	private enum hasFrameUpdate = derivedMembers.canFind("frameUpdate");
	private enum hasPhysicsPreStepUpdate = derivedMembers.canFind("physicsPreStepUpdate");
	private enum hasPhysicsPostStepUpdate = derivedMembers.canFind("physicsPostStepUpdate");

	private ComponentType[] components;

	void registerOptionals(RootDispatcher rootDispatcher)
	{
		static if(hasFrameUpdate)
		{
			rootDispatcher.frameUpdaters ~= &frameUpdate;
		}
		static if(hasPhysicsPreStepUpdate)
		{
			rootDispatcher.physicsPreStepUpdaters ~= &physicsPreStepUpdate;
		}
		static if(hasPhysicsPostStepUpdate)
		{
			rootDispatcher.physicsPostStepUpdaters ~= &physicsPostStepUpdate;
		}
	}

	override void add(ComponentType component)
	{
		components ~= component;
		component.onDestruction += &componentDestructionEventHandler;
	}

	private void componentDestructionEventHandler(ComponentType.ComponentBaseType component)
	{
		import kratos.util : unstableRemove, staticCast;
		unstableRemove(components, component.staticCast!ComponentType);
		components.assumeSafeAppend();
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

	static if(hasPhysicsPreStepUpdate)
	{
		void physicsPreStepUpdate()
		{
			foreach(component; components[])
			{
				component.physicsPreStepUpdate();
			}
		}
	}

	static if(hasPhysicsPostStepUpdate)
	{
		void physicsPostStepUpdate()
		{
			foreach(component; components[])
			{
				component.physicsPostStepUpdate();
			}
		}
	}
}