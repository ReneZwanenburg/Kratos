module kratos.scene;

import kratos.entity;
import std.container : Array;

class Scene
{
	string name;
	Array!Entity entities;

	this(string name = null)
	{
		this.name = name;
	}

	void merge(Scene scene)
	{
		entities ~= scene.entities;
		scene.entities.clear();
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