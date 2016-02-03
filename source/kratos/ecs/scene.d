module kratos.ecs.scene;

import std.container.array;

import kratos.ecs.component;
import kratos.ecs.entity;
import kratos.ecs.eventdispatcher;

import kvibe.data.json;

import std.experimental.logger;

public abstract class SceneComponent
{
	mixin ComponentBasicImpl!Scene;
	
	final @property
	{
		inout(Scene) scene() inout
		{
			return owner;
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

	private RootDispatcher _rootDispatcher;

	this(string name = null)
	{
		_rootDispatcher = new RootDispatcher();
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

		string name() const
		{
			return _name;
		}

		void name(string newName)
		{
			_name = newName.length ? newName : "Anonymous Scene";
		}

		RootDispatcher rootDispatcher()
		{
			return _rootDispatcher;
		}
	}

	public void merge(Json entityRepresentation, Json function(string) loadJson)
	{
		auto taskRunner = delayedTaskRunnerInstance;
		mergeImpl(entityRepresentation, loadJson, taskRunner);
		taskRunner.runTasks();
	}

	private void mergeImpl(Json entityRepresentation, Json function(string) loadJson, InitializationTaskRunner taskRunner)
	{
		if(entityRepresentation.type == Json.Type.array)
		{
			foreach(entity; entityRepresentation[])
			{
				mergeImpl(entity, loadJson, taskRunner);
			}
		}
		else if(entityRepresentation.type == Json.Type.object)
		{
			Entity.deserialize(this, entityRepresentation, taskRunner);
		}
		else if(entityRepresentation.type == Json.Type.string)
		{
			mergeImpl(loadJson(entityRepresentation.get!string), loadJson, taskRunner);
		}
		else assert(false);
	}

	public static Scene deserialize(Json representation, Json function(string) loadJson)
	{
		auto scene = new Scene(representation["name"].opt!string);
		auto taskRunner = delayedTaskRunnerInstance;

		info("Deserializing Scene ", scene.name);

		auto componentsRepresentation = representation["components"];
		if(componentsRepresentation.type != Json.Type.undefined)
		{
			scene._components.mergeImpl(componentsRepresentation, taskRunner);
		}

		auto entitiesRepresentation = representation["entities"];
		if(entitiesRepresentation.type != Json.Type.undefined)
		{
			scene.mergeImpl(entitiesRepresentation, loadJson, taskRunner);
		}

		taskRunner.runTasks();

		return scene;
	}
	
	Json serialize()
	{
		info("Serializing Scene ", name);

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
