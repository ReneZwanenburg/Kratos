module kratos.ecs.entity;

import kratos.ecs.component;
import kratos.ecs.scene;

import vibe.data.json;

public abstract class Component
{
	package static Entity constructingOwner;

	private Entity _owner;

	protected this()
	{
		assert(constructingOwner !is null);
		this._owner = constructingOwner;
	}

	final @property
	{
		inout(Entity) owner() inout
		{
			return _owner;
		}

		inout(Scene) scene() inout
		{
			return owner.scene;
		}
	}


	package static auto resolveDependency(FieldType, Dependency dependency)(Entity owner)
	{
		enum allowDerived = dependency.allowDerived;

		static if(is(FieldType : Component))
		{
			return owner.components.firstOrAdd!(FieldType, allowDerived);
		}
		else static if(is(FieldType : SceneComponent))
		{
			return owner.scene.components.firstOrAdd!(FieldType, allowDerived);
		}
		else static assert(false, "Invalid Dependency type: " ~ T.stringof);
	}
}

public final class Entity
{
	alias Components = ComponentContainer!Component;

	private Components _components;
	private Scene _scene;
	private string _name;

	package this(Scene scene, string name)
	{
		assert(scene !is null);
		this._scene = scene;
		_components = Components(this);
		this.name = name;
	}

	@property
	{
		inout(Scene) scene() inout
		{
			return _scene;
		}

		auto components()
		{
			return _components.getRef();
		}

		string name()
		{
			return _name;
		}

		void name(string newName)
		{
			_name = newName.length ? newName : "Anonymous Entity";
		}
	}

	package static void deserialize(Scene owner, Json representation)
	{
		auto entity = owner.createEntity(representation["name"].opt!string);

		auto componentsRepresentation = representation["components"];
		if(componentsRepresentation.type != Json.Type.undefined)
		{
			entity._components.deserialize(componentsRepresentation);
		}
	}

	package Json serialize()
	{
		auto json = Json.emptyObject;
		json["name"] = name;
		json["components"] = _components.serialize();
		return json;
	}
}
