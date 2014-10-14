module kratos.scene;

import kratos.entity;
import kratos.util : SerializableArray;

class Scene
{
	string name;
	SerializableArray!Entity entities;

	this(string name = null)
	{
		this.name = name;
	}

	Entity createEntity(string name = null)
	{
		auto entity = new Entity(name);
		entities ~= entity;
		return entity;
	}

	void addEntity(Entity entity)
	{
		entities ~= entity;
	}

	Entity find(string name)
	{
		import std.algorithm : find;
		auto result = entities[].find!(a => a.name == name);
		return result.empty ? null : result.front;
	}

	auto getComponents(T, AllowDerived derived = AllowDerived.no)()
	{
		import std.algorithm : joiner, map;
		return entities[].map!(a => a.getComponents!(T, derived)).joiner;
	}
}