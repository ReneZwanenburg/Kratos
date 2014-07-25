module kratos.entity;

import std.container : Array;
import std.typecons : Flag;

final class Entity
{
	public	string			name;
	private	Array!Component	_components;

	T addComponent(T)() if(is(T : Component))
	{
		auto component = ComponentFactory!T.build(this);
		component._owner = this;
		_components.insertBack(component);
		return component;
	}

	alias AllowDerived = Flag!"AllowDerived";

	auto getComponents(T, AllowDerived derived = AllowDerived.no)()
	{
		import std.algorithm : filter, map;
		static if(derived)
		{
			return _components[].map!(a => cast(T)a).filter!(a => a !is null);
		}
		else
		{
			return _components[].filter!(a => a.classinfo == typeid(T)).map!(a => cast(T)(cast(void*)a));
		}
	}

	T getComponent(T, AllowDerived derived = AllowDerived.no)()
	{
		auto range = getComponents!(T, derived);
		return range.empty ? null : range.front;
	}

	T getOrAddComponent(T, AllowDerived derived = AllowDerived.no)()
	{
		auto component = getComponent!(T, derived);
		return component is null ? addComponent!T : component;
	}
}

abstract class Component
{
	private Entity _owner;
}

// Used for Components depending on another Component on the same Entity
struct dependency{};
enum isDependency(T) = is(T == dependency);


private template ComponentFactory(T) if(is(T : Component))
{
	T build(Entity owner)
	{
		//TODO: Don´t use GC
		auto component = new T;

		import std.traits;
		foreach(i, FT; typeof(T.tupleof))
		{
			import std.typetuple;
			static if(anySatisfy!(isDependency, __traits(getAttributes, T.tupleof[i])))
			{
				component.tupleof[i] = owner.getOrAddComponent!FT;
			}
		}

		return component;
	}
}