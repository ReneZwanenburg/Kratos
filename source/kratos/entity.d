module kratos.entity;

import std.container : Array;
import std.typecons : Flag;

final class Entity
{
	public	string			name;
	private	Array!Component	_components;

	T addComponent(T)() if(is(T : Component))
	{
		//TODO: Don't use the GC
		auto component = new T;
		component.owner = this;
		_components.insertBack(component);
		return _components;
	}

	alias AllowDerived = Flag!"AllowDerived";

	auto getComponents(T, AllowDerived derived = AllowDerived.no)()
	{
		import std.algorithm : filter, map;
		static if(derived)
		{
			//TODO: support finding derived components
			static assert(false, "Not implemented yet");
		}
		else
		{
			return _components[].filter!(a => a.classinfo == typeid(T)).map!(a => cast(T)(cast(void*)a));
		}
	}
}

abstract class Component
{
	private Entity _owner;
}
