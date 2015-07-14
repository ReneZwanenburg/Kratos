module kratos.ecs.component;

import std.container : Array;
import std.typecons : Flag;
import std.traits : ReturnType, Unqual;

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
		ComponentBaseType.constructingOwner = _owner;
		auto component = new T();
		ComponentBaseType.constructingOwner = null;

		// Add the component to the array before initializing, so cyclic dependencies can be resolved
		_components.insertBack(component);
		ComponentInteraction!T.initialize(component);

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


	package void deserialize(Json containerRepresentation)
	{
		assert(containerRepresentation.type == Json.Type.array);

		foreach(componentRepresentation; containerRepresentation[])
		{
			auto fullTypeName = componentRepresentation["type"].get!string;
			auto serializer = fullTypeName in Serializers!ComponentBaseType;
			assert(serializer, fullTypeName ~ " has not been registered for serialization");
			serializer.deserialize(_owner, componentRepresentation); // Added to _components in deserializer
		}
	}

	package Json serialize()
	{
		auto json = Json.emptyArray;

		foreach(component; this.all)
		{
			auto fullTypeName = component.classinfo.name;
			auto serializer = fullTypeName in Serializers!ComponentBaseType;
			assert(serializer, fullTypeName ~ " has not been registered for serialization");
			json ~= serializer.serialize(component);
		}

		return json;
	}

}

package mixin template ComponentBasicImpl(OwnerType)
{
	package static OwnerType constructingOwner;

	private OwnerType _owner;
	
	protected this()
	{
		assert(constructingOwner !is null);
		this._owner = constructingOwner;
	}
	
	final @property
	{
		inout(OwnerType) owner() inout
		{
			return _owner;
		}
	}
	
	package alias ComponentBaseType = Unqual!(typeof(this));
}

template ComponentInteraction(ComponentType)
{

	private void initialize(ComponentType component)
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
	abstract void deserialize(OwnerType, Json);
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
		return representation;
	}

	override void deserialize(OwnerType owner, Json representation)
	{
		assert(fullTypeName == representation["type"].get!string, "Component representation ended up in the wrong deserializer");
		assert(owner, "Null owner provided");
		
		auto componentRepresentation = representation["representation"];
		
		if(componentRepresentation.type == Json.Type.undefined)
		{
			owner.components.add!ComponentType;
		}
		else
		{
			ComponentType.ComponentBaseType.constructingOwner = owner;
			auto component = deserializeJson!ComponentType(componentRepresentation);
			ComponentType.ComponentBaseType.constructingOwner = null;

			owner.components._components.insertBack(component);
			ComponentInteraction!ComponentType.initialize(component);
		}
	}
}

private template Serializers(ComponentBaseType)
{
	private ComponentSerializer!ComponentBaseType[string] Serializers;
}
