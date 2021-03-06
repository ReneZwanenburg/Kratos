﻿module kratos.ecs.entity;

import kratos.ecs.component;
import kratos.ecs.scene;

import vibe.data.json;

import std.experimental.logger;

public abstract class Component
{
	mixin ComponentBasicImpl!Entity;

	final @property
	{
		inout(Scene) scene() inout
		{
			return owner.scene;
		}
	}

	static auto resolveDependency(FieldType, Dependency dependency)(Entity owner)
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

		string name() const
		{
			return _name;
		}

		void name(string newName)
		{
			_name = newName.length ? newName : "Anonymous Entity";
		}
	}

	package static void deserialize(Scene owner, Json representation, InitializationTaskRunner taskRunner)
	{
		auto entity = owner.createEntity(representation["name"].opt!string);

		info("Deserializing Entity ", entity.name);

		auto componentsRepresentation = representation["components"];
		if(componentsRepresentation.type != Json.Type.undefined)
		{
			entity._components.mergeImpl(componentsRepresentation, taskRunner);
		}
	}

	package Json serialize()
	{
		info("Serializing Entity ", name);

		auto json = Json.emptyObject;
		json["name"] = name;
		json["components"] = _components.serialize();
		return json;
	}
}
