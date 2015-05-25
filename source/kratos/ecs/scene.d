module kratos.ecs.scene;

import std.container.array;

import kratos.ecs.component;
import kratos.ecs.entity;

import vibe.data.json;

public abstract class SceneComponent
{
	package static Scene constructingOwner;

	private Scene _owner;

	protected this()
	{
		assert(constructingOwner !is null);
		this._owner = constructingOwner;
	}

	final @property
	{
		inout(Scene) owner() inout
		{
			return _owner;
		}
	}


	package static auto resolveDependency(FieldType, Dependency dependency)(Scene owner)
	{
		static if(is(FieldType : SceneComponent))
		{
			enum allowDerived = dependency.allowDerived;
			return owner.components.firstOrAdd!(FieldType, allowDerived);
		}
		else static assert(false, "Invalid Dependency type: " ~ T.stringof);
	}
}

public final class Scene
{
	alias Components = ComponentContainer!SceneComponent;

	private Components _components;
	private Array!Entity _entities;
	private string _name;

	this(string name = null)
	{
		_components = Components(this);
		this.name = name;
	}

	Entity createEntity(string name = null)
	{
		auto entity = new Entity(this, name);
		_entities.insertBack(entity);
		return entity;
	}

	@property
	{
		auto entities()
		{
			return _entities[];
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
			_name = newName.length ? newName : "Anonymous Scene";
		}
	}

	public static Scene fromRepresentation(Json representation)
	{
		auto scene = new Scene(representation["name"].opt!string);

		auto componentsRepresentation = representation["components"];
		if(componentsRepresentation.type != Json.Type.undefined)
		{
			scene._components.deserialize(componentsRepresentation);
		}

		auto entitiesRepresentation = representation["entities"];
		if(entitiesRepresentation.type != Json.Type.undefined)
		{
			assert(entitiesRepresentation.type == Json.Type.array);

			foreach(entityRepresentation; entitiesRepresentation[])
			{
				Entity.deserialize(scene, entityRepresentation);
			}
		}

		return scene;
	}
	
	Json toRepresentation()
	{
		auto json = Json.emptyObject;

		json["name"] = name;
		json["components"] = _components.serialize();

		auto entitiesJson = Json.emptyArray;
		foreach(entity; entities)
		{
			entitiesJson ~= entity.serialize();
		}

		json["entities"] = entitiesJson;

		return json;
	}
}
