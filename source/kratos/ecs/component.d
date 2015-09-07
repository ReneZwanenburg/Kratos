module kratos.ecs.component;

import std.container : Array;
import std.typecons : Flag;
import std.traits : ReturnType, Unqual;

import kratos.util : Event;

import vibe.data.json;

public import vibe.data.serialization : asArray, byName, ignore, name, optional;

alias AllowDerived = Flag!"AllowDerived";
private alias DefaultAllowDerived = AllowDerived.yes;


struct Dependency
{
	AllowDerived allowDerived = DefaultAllowDerived;
}

@property Dependency dependency(AllowDerived allowDerived = DefaultAllowDerived)
{
	return Dependency(allowDerived);
}

//TODO: Make generic Ref struct
struct ComponentContainerRef(ComponentBaseType)
{
	private ComponentContainer!ComponentBaseType* _container;

	@disable this();

	private this(ComponentContainer!ComponentBaseType* container)
	{
		this._container = container;
	}

	alias release this;

	public @property ref release()
	{
		return *_container;
	}
}

struct ComponentContainer(ComponentBaseType)
{
	alias OwnerType = typeof(ComponentBaseType.init.owner);

	private Array!ComponentBaseType _components;
	private OwnerType _owner;

	@disable this();

	@disable this(this);

	this(OwnerType owner)
	{
		assert(owner !is null);
		this._owner = owner;
	}

	package auto getRef()
	{
		return ComponentContainerRef!ComponentBaseType(&this);
	}

	T add(T)() if(is(T : ComponentBaseType))
	{
		auto component = add!T(immediateTaskRunnerInstance);
		component.assignId(null);
		return component;
	}

	private T add(T)(InitializationTaskRunner taskRunner) if(is(T : ComponentBaseType))
	{
		ComponentBaseType.constructingOwner = _owner;
		auto component = new T();
		ComponentBaseType.constructingOwner = null;
		
		// Add the component to the array before initializing, so cyclic dependencies can be resolved
		_components.insertBack(component);
		ComponentInteraction!T.initialize(component, taskRunner);
		
		return component;
	}

	T first(T, AllowDerived derived = DefaultAllowDerived)() if(is(T : ComponentBaseType))
	{
		auto range = all!(T, derived);
		return range.empty ? null : range.front;
	}

	auto all(T, AllowDerived derived = DefaultAllowDerived)()  if(is(T : ComponentBaseType))
	{
		import std.traits : isFinalClass;
		import std.algorithm.iteration : map, filter;

		static if(derived && !isFinalClass!T)
		{
			return
				_components[]
				.map!(a => cast(T)a)
				.filter!(a => a !is null);
		}
		else
		{
			return
				_components[]
				.filter!(a => a.classinfo is T.classinfo)
				.map!(a => cast(T)(cast(void*)a));
		}
	}

	auto all()
	{
		return _components[];
	}

	T firstOrAdd(T, AllowDerived derived = DefaultAllowDerived)() if(is(T : ComponentBaseType))
	{
		auto component = first!(T, derived);
		return component is null ? add!T : component;
	}


	package void deserialize(Json containerRepresentation, InitializationTaskRunner taskRunner)
	{
		assert(containerRepresentation.type == Json.Type.array);

		foreach(componentRepresentation; containerRepresentation[])
		{
			auto fullTypeName = componentRepresentation["type"].get!string;
			auto serializer = fullTypeName in Serializers!ComponentBaseType;
			assert(serializer, fullTypeName ~ " has not been registered for serialization");
			serializer.deserialize(_owner, componentRepresentation, taskRunner); // Added to _components in deserializer
		}
	}

	package Json serialize()
	{
		auto json = Json.emptyArray;

		foreach(component; this.all)
		{
			auto fullTypeName = component.classinfo.name;
			auto serializer = fullTypeName in Serializers!ComponentBaseType;

			if(serializer !is null)
			{
				json ~= serializer.serialize(component);
			}
			else
			{
				// Log?
			}
		}

		return json;
	}

}

package mixin template ComponentBasicImpl(OwnerType)
{
	import std.uuid : UUID, randomUUID, md5UUID, UUIDParsingException;

	package static OwnerType constructingOwner;

	private OwnerType _owner;
	private UUID _id;
	public Event!ComponentBaseType onDestruction;
	
	protected this()
	{
		assert(constructingOwner !is null);
		this._owner = constructingOwner;
	}

	~this()
	{
		onDestruction.raise(this);
	}
	
	final @property
	{
		inout(OwnerType) owner() inout
		{
			return _owner;
		}

		UUID id() const
		{
			return _id;
		}
	}

	/// Internal use only.
	public void assignId(string idString)
	{
		assert(_id.empty);

		if(idString.length == 0)
		{
			_id = randomUUID();
		}
		else if(idString.length == 36)
		{
			try
			{
				_id = UUID(idString);
			}
			catch(UUIDParsingException)
			{
				_id = md5UUID(idString);
			}
		}
		else
		{
			_id = md5UUID(idString);
		}
	}
	
	package alias ComponentBaseType = Unqual!(typeof(this));
}

template ComponentInteraction(ComponentType)
{

	private void initialize(ComponentType component, InitializationTaskRunner taskRunner)
	{
		registerAtDispatcher(component);

		taskRunner.addTask(&resolveDependencies, component);
	}

	private void registerAtDispatcher(ComponentType component)
	{
		import std.traits : BaseClassesTuple;
		alias ParentType = BaseClassesTuple!ComponentType[0];
		static if(!is(ParentType == ComponentType.ComponentBaseType))
		{
			ComponentInteraction!ParentType.registerAtDispatcher(component);
		}

		component.scene.rootDispatcher.getDispatcher!ComponentType.add(component);
	}

	private void resolveDependencies(ComponentType component, InitializationTaskRunner taskRunner)
	{
		import std.traits;
		import vibe.internal.meta.uda : findFirstUDA;

		foreach(i, T; typeof(ComponentType.tupleof))
		{
			enum uda = findFirstUDA!(Dependency, ComponentType.tupleof[i]);
			static if(uda.found)
			{
				component.tupleof[i] = ComponentType.resolveDependency!(T, uda.value)(component.owner);
			}
		}

		taskRunner.addTask(&callInitializer, component);
	}

	private void callInitializer(ComponentType component, InitializationTaskRunner taskRunner)
	{
		import std.traits : BaseClassesTuple, hasMember;
		alias ParentType = BaseClassesTuple!ComponentType[0];
		static if(!is(ParentType == ComponentType.ComponentBaseType))
		{
			ComponentInteraction!ParentType.callInitializer(component);
		}

		//TODO: Type and arg checking, make reusable
		//TODO: Call all initializers only after full deserialization
		static if(hasMember!(ComponentType, "initialize"))
		{
			component.initialize();
		}
	}
}

public void registerComponent(ComponentType)()
{
	auto serializer = new ComponentSerializerImpl!ComponentType();
	Serializers!(ComponentType.ComponentBaseType)[serializer.fullTypeName] = serializer;
}

private abstract class ComponentSerializer(ComponentBaseType)
{
	private alias OwnerType = typeof(ComponentBaseType.init.owner());

	abstract Json serialize(ComponentBaseType);
	abstract void deserialize(OwnerType, Json, InitializationTaskRunner);
}

private class ComponentSerializerImpl(ComponentType) : ComponentSerializer!(ComponentType.ComponentBaseType)
{
	const string fullTypeName;

	this()
	{
		fullTypeName = typeid(ComponentType).name;
		import std.experimental.logger : info;
		info("Instantiating serializer for ", fullTypeName);
	}

	override Json serialize(ComponentType.ComponentBaseType componentBase)
	{
		assert(typeid(ComponentType) == typeid(componentBase), "Component ended up in the wrong serializer");

		import kratos.util : staticCast;
		auto component = staticCast!ComponentType(componentBase);
		
		auto representation = Json.emptyObject;
		representation["type"] = fullTypeName;
		representation["representation"] = serializeToJson(component);
		representation["id"] = component.id.toString();
		return representation;
	}

	override void deserialize(OwnerType owner, Json representation, InitializationTaskRunner taskRunner)
	{
		assert(fullTypeName == representation["type"].get!string, "Component representation ended up in the wrong deserializer");
		assert(owner, "Null owner provided");
		
		auto componentRepresentation = representation["representation"];

		ComponentType component;
		
		if(componentRepresentation.type == Json.Type.undefined)
		{
			component = owner.components.add!ComponentType(taskRunner);
		}
		else
		{
			ComponentType.ComponentBaseType.constructingOwner = owner;
			component = deserializeJson!ComponentType(componentRepresentation);
			ComponentType.ComponentBaseType.constructingOwner = null;

			owner.components._components.insertBack(component);
			ComponentInteraction!ComponentType.initialize(component, taskRunner);
		}

		component.assignId(representation["id"].opt!string);
	}
}

private template Serializers(ComponentBaseType)
{
	private ComponentSerializer!ComponentBaseType[string] Serializers;
}

package abstract class InitializationTaskRunner
{
	alias Task = void function(Object argument, InitializationTaskRunner taskRunner);

	protected abstract void addTaskImpl(Task task, Object argument);

	public void addTask(T)(void function (T argument, InitializationTaskRunner taskRunner)task, T argument)
	{
		addTaskImpl(cast(Task)task, argument);
	}
}

private ImmediateTaskRunner immediateTaskRunnerInstance;
package DelayedTaskRunner delayedTaskRunnerInstance;

static this()
{
	immediateTaskRunnerInstance = new ImmediateTaskRunner();
	delayedTaskRunnerInstance = new DelayedTaskRunner();
}

private final class ImmediateTaskRunner : InitializationTaskRunner
{
	override void addTaskImpl(Task task, Object argument)
	{
		task(argument, this);
	}
}

private final class DelayedTaskRunner : InitializationTaskRunner
{
	private static struct TaskArgumentPair
	{
		Task task;
		Object argument;
	}

	private TaskArgumentPair[] frontBuffer, backBuffer;

	override void addTaskImpl(Task task, Object argument)
	{
		frontBuffer ~= TaskArgumentPair(task, argument);
	}

	void runTasks()
	{
		while(frontBuffer.length > 0)
		{
			swapBuffers();

			foreach(taskArgPair; backBuffer)
			{
				taskArgPair.task(taskArgPair.argument, this);
			}

			backBuffer.length = 0;
		}
	}

	private void swapBuffers()
	{
		auto tmp = backBuffer;
		backBuffer = frontBuffer;
		frontBuffer = tmp;
		assert(frontBuffer.length == 0);
		frontBuffer.assumeSafeAppend();
	}
}