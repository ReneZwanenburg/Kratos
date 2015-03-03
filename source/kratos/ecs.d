module kratos.ecs;

import kratos.util : SerializableArray;
import std.container : Array;
import std.typecons : Flag;
import vibe.data.json;
import std.experimental.logger;

public import vibe.data.serialization;


alias AllowDerived = Flag!"AllowDerived";
private alias DefaultAllowDerived = AllowDerived.yes;

public final class Entity
{
	private EntityComponentContainer components;
	private Scene _scene;
	private string _name;

	alias componentContainer this;

	private this(Scene scene, string name)
	{
		assert(scene !is null);
		this.name = name;
		this._scene = scene;
		this.components = EntityComponentContainer(this);
	}

	public @property
	{
		Scene scene()
		{
			return _scene;
		}

		void name(string newName)
		{
			_name = newName.length ? newName : "Anonymous Entity";
		}

		string name() const
		{
			return _name;
		}

		ref EntityComponentContainer componentContainer()
		{
			return components;
		}
	}
	
	Json toRepresentation()
	{
		info("Serializing Entity ", name);
		
		auto rep = Json.emptyObject;
		rep["name"] = name;
		rep["components"] = serializeToJson(components);
		
		return rep;
	}
	
	// Nastiness
	private static Entity currentlyDeserializing;

	static Entity fromRepresentation(Json json)
	{
		assert(Scene.currentlyDeserializing !is null);
		auto entity = Scene.currentlyDeserializing.createEntity(json["name"].get!string);
		info("Deserializing Entity ", entity.name);

		entity.components = deserializeJson!(typeof(entity.components))(json["components"]);

		return entity;
	}

	//Workaround for opCast forwarding to alias this
	public void* opCast(T)() if(is(T == void*))
	{
		return *cast(void**)(&this);
	}
}

public final class Scene
{
	private SceneComponentContainer components;

	private string _name;
	private SerializableArray!Entity _entities;

	alias componentContainer this;

	public this(string name = null)
	{
		this.name = name;
		this.components = SceneComponentContainer(this);
	}

	public Entity createEntity(string name = null)
	{
		//TODO: Don't use GC
		auto entity = new Entity(this, name);
		_entities.insertBack(entity);
		return entity;
	}

	public @property
	{
		void name(string newName)
		{
			this._name = newName.length ? newName : "Anonymous Scene";
		}

		string name() const
		{
			return _name;
		}

		ref SceneComponentContainer componentContainer()
		{
			return components;
		}

		auto entities()
		{
			return _entities[];
		}
	}

	Json toRepresentation()
	{
		import std.algorithm : map;
		import std.array : array;
		
		info("Serializing Scene ", name);

		auto rep = Json.emptyObject;
		rep["name"] = name;
		rep["entities"] = serializeToJson(_entities);
		rep["components"] = serializeToJson(components);
		
		return rep;
	}
	
	// Nastiness
	private static Scene currentlyDeserializing;
	
	static Scene fromRepresentation(Json json)
	{
		auto scene = new Scene(json["name"].get!string);
		info("Deserializing Scene ", scene.name, " entities");

		assert(currentlyDeserializing is null);
		currentlyDeserializing = scene;
		scope(exit) currentlyDeserializing = null;

		//TODO: Handle Entity component <-> Scene component interdependencies
		scene.components = deserializeJson!(typeof(scene.components))(json["components"]);

		foreach(entityJson; json["entities"])
		{
			// Added through Entity.fromRepresentation() -> currentlyDeserializing -> createEntity
			// Yeah yeah, the horror, I know..
			deserializeJson!(Entity)(entityJson);
		}

		return scene;
	}
	
	//Workaround for opCast forwarding to alias this
	public void* opCast(T)() if(is(T == void*))
	{
		return *cast(void**)(&this);
	}
}

private mixin template BaseComponent(OwnerType)
{
	private static OwnerType constructingOwner;
	private OwnerType _owner;

	this()
	{
		assert(constructingOwner !is null);
		_owner = constructingOwner;
	}
	
	public final @property
	{
		OwnerType owner()
		{
			return owner;
		}

		const(OwnerType) owner() const
		{
			return owner;
		}
	}
}

public abstract class Component
{
	mixin BaseComponent!Entity;

	public final @property
	{
		Scene scene()
		{
			return owner.scene;
		}
	}
}

public abstract class SceneComponent
{
	mixin BaseComponent!Scene;
}

auto @property dependency(AllowDerived allowDerived = AllowDerived.yes)
{
	return Dependency(allowDerived);
}

struct Dependency
{
	AllowDerived allowDerived = AllowDerived.yes;
};
enum isDependency(T) = is(T == Dependency);

private alias EntityComponentContainer = ComponentContainer!(Component, Entity);
private alias SceneComponentContainer = ComponentContainer!(SceneComponent, Scene);

private struct ComponentContainer(CT, OT) if(is(CT == Component) || is(CT == SceneComponent))
{
	private alias ComponentRT = ComponentRuntime!(OT, CT);
	private Array!CT components;
	private OT owner;
	@disable this();

	private this(OT owner)
	{
		assert(owner !is null);
		this.owner = owner;
	}
	
	~this()
	{
		import std.range : retro;
		foreach(component; components[].retro)
		{
			ComponentRT.componentDestroyer[component.classinfo](component);
		}
	}

	
	// Can be non-copyable b/c serializercopies structs around
	//TODO: Make sure noone else can copy this struct, maybe only provide access through wrapper?
	//@disable this(this);

	T addComponent(T, Args...)(Args args) if(is(T : CT))
	{
		info("Adding ", T.stringof, " to ", owner.name);
		//TODO: Instantiate on both CT and T
		return ComponentFactory!(T).build(owner, args);
	}
	
	auto getComponents(T, AllowDerived derived = DefaultAllowDerived)()
	{
		import std.algorithm : filter, map;
		import std.traits : isFinalClass;

		static if(derived && !isFinalClass!T)
		{
			return components[].map!(a => cast(T)a).filter!(a => a !is null);
		}
		else
		{
			return components[].filter!(a => a.classinfo == typeid(T)).map!(a => cast(T)(cast(void*)a));
		}
	}
	
	T getComponent(T, AllowDerived derived = DefaultAllowDerived)()
	{
		auto range = getComponents!(T, derived);
		return range.empty ? null : range.front;
	}

	T getOrAddComponent(T, AllowDerived derived = DefaultAllowDerived)()
	{
		auto component = getComponent!(T, derived);
		return component is null ? addComponent!T : component;
	}

	Json[] toRepresentation()
	{
		import std.algorithm : map;
		import std.array : array;
		return components[].map!(a => ComponentRT.componentSerializer[a.classinfo](a)).array;
	}

	static ComponentContainer fromRepresentation(Json[] json)
	{
		auto container = ComponentContainer(OT.currentlyDeserializing);
		
		foreach(description; json)
		{
			auto componentFullName = description["type"].get!string;
			
			if(auto typeInfo = TypeInfo_Class.find(componentFullName))
			{
				if(auto deserializer = typeInfo in ComponentRT.componentDeserializer)
				{
					(*deserializer)(container.owner, description["representation"]);
				}
				else
				{
					assert(false, "No deserializer registered for " ~ componentFullName ~ ". Use RegisterComponent if only used from data files");
				}
			}
			else
			{
				assert(false, "No typeinfo found for Component " ~ componentFullName);
			}
		}

		return container;
	}
}

mixin template RegisterComponent()
{
	private void KratosComponentRegistrationHelper()
	{
		alias factory = ComponentFactory!(typeof(this));
		factory.instantiationHelper();
	}
}

template ComponentFactory(T)
{
private:
	pragma(msg, "ComponentFactory instantiated for " ~ T.stringof);
	
	static if(is(T : Component))
	{
		alias ComponentBaseType = Component;
		alias OwnerType = Entity;
	}
	else static if(is(T : SceneComponent))
	{
		alias ComponentBaseType = SceneComponent;
		alias OwnerType = Scene;
	}
	else static assert(false, T.stringof ~ " is not a component type");

	alias ComponentRT = ComponentRuntime!(OwnerType, ComponentBaseType);

	//TODO: Kill
	T[] liveComponents;

	T build(Args...)(OwnerType owner, Args args)
	{
		//TODO: Don´t use GC
		ComponentBaseType.constructingOwner = owner;
		scope(exit) ComponentBaseType.constructingOwner = null;
		return onComponentCreation(new T(args), owner);
	}
	
	T onComponentCreation(T component, OwnerType owner)
	{
		owner.components.components.insertBack(component);
		liveComponents ~= component;
		
		foreach(i, FT; typeof(T.tupleof))
		{
			import vibe.internal.meta.uda;
			enum uda = findFirstUDA!(Dependency, T.tupleof[i]);
			static if(uda.found)
			{
				trace("Resolving dependency ", T.stringof, ".", T.tupleof[i].stringof);
				component.tupleof[i] = resolveDependency!(FT, __traits(getAttributes, T.tupleof[i])[uda.index].allowDerived)(owner);
			}
		}
		
		component.callOptional!"initialize"();
		
		return component;
	}
	
	void destroy(ComponentBaseType component)
	{
		assert(component.classinfo == T.classinfo);
		
		info("Destroying Component ", T.stringof, " of ", component.owner.name);
		
		import std.algorithm : countUntil;
		liveComponents[liveComponents.countUntil!"a is b"(component)] = liveComponents[$-1];
		liveComponents.length--;
	}
	
	T deserialize(OwnerType owner, Json json)
	{
		info("Deserializing Component ", T.stringof, " of ", owner.name);
		
		if(json.type == Json.Type.undefined) // If 'representation' is missing
		{
			return build(owner);
		}
		else
		{
			ComponentBaseType.constructingOwner = owner;
			scope(exit) ComponentBaseType.constructingOwner = null;
			//TODO: Don´t use GC
			return onComponentCreation(json.deserializeJson!T, owner);
		}
	}
	
	Json serialize(T component)
	{
		info("Serializing Component ", T.stringof, " of ", component.owner.name);
		
		Json rep = Json.emptyObject;
		rep["type"] = T.classinfo.name;
		rep["representation"] = serializeToJson(component);
		return rep;
	}
	
	void callOptional(string name)(T component)
	{
		import std.traits : isCallable;
		import std.algorithm : among;

		//TODO: Handle inheritance
		static if(name.among(__traits(derivedMembers, T)))
		{
			static if(mixin("isCallable!(T."~name~")"))
			{
				mixin("component."~name~"();");
			}
		}
	}
	
	static this()
	{
		import std.traits : isCallable;
		import std.algorithm : among;
		
		info("Registering Component ", T.stringof);
		
		ComponentRT.componentDestroyer		[T.classinfo] = &destroy;
		ComponentRT.componentDeserializer	[T.classinfo] = &deserialize;
		ComponentRT.componentSerializer		[T.classinfo] = cast(ComponentRT.ComponentSerializeFunction)&serialize;
		
		static if("frameUpdate".among(__traits(derivedMembers, T)))
		{
			static if(isCallable!(T.frameUpdate))
			{
				frameUpdateDispatchers ~= {
					foreach(component; liveComponents) component.frameUpdate();
				};
			}
		}
	}
	
	public void instantiationHelper()
	{
		
	}
}

private CT resolveDependency(CT, AllowDerived allowDerived, OT)(OT owner)
{
	static if(is(OT == Scene))
	{
		static if(is(CT : Component))
		{
			static assert(false, "SceneComponents can't depend on entity components");
		}
		else if(is(CT : SceneComponent))
		{
			return owner.getOrAddComponent!(CT, allowDerived);
		}
		else static assert(false, "Invalid Component Type: " ~ CT.stringof);
	}
	else static if(is(OT == Entity))
	{
		static if(is(CT : Component))
		{
			return owner.getOrAddComponent!(CT, allowDerived);
		}
		else if(is(CT : SceneComponent))
		{
			return owner.scene.getOrAddComponent!(CT, allowDerived);
		}
		else static assert(false, "Invalid Component Type: " ~ CT.stringof);
	}
	else static assert(false, "Invalid owner type: " ~ OT.stringof);
}

private template ComponentRuntime(OwnerType, ComponentBaseType)
{
	private alias ComponentDestroyFunction = void function(ComponentBaseType);
	private alias ComponentDeserializeFunction = ComponentBaseType function(OwnerType, Json);
	private alias ComponentSerializeFunction = Json function(ComponentBaseType);
	
	private ComponentDestroyFunction[const TypeInfo_Class] componentDestroyer;
	private ComponentDeserializeFunction[const TypeInfo_Class] componentDeserializer;
	private ComponentSerializeFunction[const TypeInfo_Class] componentSerializer;
}

private alias FrameUpdateDispatch = void function();
private FrameUpdateDispatch[] frameUpdateDispatchers;
package void dispatchFrameUpdate()
{
	foreach(dispatcher; frameUpdateDispatchers) dispatcher();
}