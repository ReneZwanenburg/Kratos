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

alias AllowDerived = Flag!"AllowDerived";

// Used for Components depending on another Component on the same Entity
struct dependency
{
	AllowDerived allowDerived = AllowDerived.yes;
};
enum isDependency(T) = is(T == dependency);


private template ComponentFactory(T) if(is(T : Component))
{
	T build(Entity owner)
	{
		//TODO: Don´t use GC
		auto component = new T;

		foreach(i, FT; typeof(T.tupleof))
		{
			import std.typetuple;
			static if(anySatisfy!(isDependency, __traits(getAttributes, T.tupleof[i])))
			{
				//TODO: Respect dependency allowDerived property
				component.tupleof[i] = owner.getOrAddComponent!FT;
			}
		}

		return component;
	}
}