module kratos.ecs;

import kratos.util : SerializableArray;
import std.container : Array;
import std.typecons : Flag;
import vibe.data.json;
import std.experimental.logger;


alias AllowDerived = Flag!"AllowDerived";
private alias DefaultAllowDerived = AllowDerived.yes;

public final class Entity
{
	mixin Composite!Component;

	private Scene _scene;
	private string _name;

	private this(Scene scene, string name)
	{
		assert(scene !is null);
		this.name = name;
		this._scene = scene;
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
	}
	
	Json toRepresentation()
	{
		import std.algorithm : map;
		import std.array : array;
		
		info("Serializing Entity ", name);
		
		auto rep = Json.emptyObject;
		rep["name"] = name;
		rep["components"] = components[].map!(a => componentSerializer[a.classinfo](a)).array;
		
		return rep;
	}

	// Nastiness
	private static Scene deserializingScene;

	static Entity fromRepresentation(Json json)
	{
		assert(deserializingScene !is null);
		auto entity = deserializingScene.createEntity(json["name"].get!string);
		
		info("Deserializing Entity ", entity.name);
		
		foreach(description; json["components"].get!(Json[]))
		{
			auto componentFullName = description["type"].get!string;
			
			if(auto typeInfo = TypeInfo_Class.find(componentFullName))
			{
				if(auto deserializer = typeInfo in componentDeserializer)
				{
					(*deserializer)(entity, description["representation"]);
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
		
		return entity;
	}
}

public final class Scene
{
	mixin Composite!SceneComponent;

	private string _name;
	private SerializableArray!Entity _entities;

	public this(string name = null)
	{
		this.name = name;
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
	}

	Json toRepresentation()
	{
		import std.algorithm : map;
		import std.array : array;
		
		info("Serializing Scene ", name);
		
		auto rep = Json.emptyObject;
		rep["name"] = name;
		rep["entities"] = serializeToJson(_entities);
		
		return rep;
	}
	
	static Scene fromRepresentation(Json json)
	{
		auto scene = new Scene(json["name"].get!string);
		info("Deserializing Scene ", scene.name, " entities");

		assert(Entity.deserializingScene is null);
		Entity.deserializingScene = scene;
		scope(exit) Entity.deserializingScene = null;

		scene._entities = deserializeJson!(typeof(scene._entities))(json["entities"]);

		return scene;
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

mixin template Composite(CT) if(is(CT == Component) || is(CT == SceneComponent))
{
	private Array!CT components;
	
	~this()
	{
		import std.range : retro;
		foreach(component; components[].retro)
		{
			componentDestroyer[component.classinfo](component);
		}
	}

	T addComponent(T, Args...)(Args args) if(is(T : CT))
	{
		info("Adding ", T.stringof, " to ", name);
		//TODO: Instantiate on both CT and T
		return ComponentFactory!T.build(this, args);
	}
	
	auto getComponents(T, AllowDerived derived = DefaultAllowDerived)()
	{
		import std.algorithm : filter, map;
		import std.traits : isFinalClass;

		static if(derived && !isFinalClass!T)
		{
			return _components[].map!(a => cast(T)a).filter!(a => a !is null);
		}
		else
		{
			return _components[].filter!(a => a.classinfo == typeid(T)).map!(a => cast(T)(cast(void*)a));
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
}

template ComponentFactory(OwnerType, ComponentBaseType, T) if(is(T : ComponentBaseType))
{
	pragma(msg, "ComponentFactory instantiated for " ~ T.stringof);


private:
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
		owner.components.insertBack(component);
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
		
		componentDestroyer		[T.classinfo] = &destroy;
		componentDeserializer	[T.classinfo] = &deserialize;
		componentSerializer		[T.classinfo] = cast(ComponentSerializeFunction)&serialize;
		
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
			return owner.GetOrAddComponent!(CT, allowDerived);
		}
		else static assert(false, "Invalid Component Type: " ~ CT.stringof);
	}
	else static if(is(OT == Entity))
	{
		static if(is(CT : Component))
		{
			return owner.GetOrAddComponent!(CT, allowDerived);
		}
		else if(is(CT : SceneComponent))
		{
			return owner.scene.GetOrAddComponent!(CT, allowDerived);
		}
		else static assert(false, "Invalid Component Type: " ~ CT.stringof);
	}
	else static assert(false, "Invalid owner type: " ~ OT.stringof);
}

private alias ComponentDestroyFunction = void function(Object);
private alias ComponentDeserializeFunction = Object function(Object, Json);
private alias ComponentSerializeFunction = Json function(Object);

private ComponentDestroyFunction[const TypeInfo_Class] componentDestroyer;
private ComponentDeserializeFunction[const TypeInfo_Class] componentDeserializer;
private ComponentSerializeFunction[const TypeInfo_Class] componentSerializer;

private alias FrameUpdateDispatch = void function();
private FrameUpdateDispatch[] frameUpdateDispatchers;
package void dispatchFrameUpdate()
{
	foreach(dispatcher; frameUpdateDispatchers) dispatcher();
}