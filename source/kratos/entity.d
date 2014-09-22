module kratos.entity;

import std.container : Array;
import std.typecons : Flag;
import std.logger;

final class Entity
{
	private	string			_name;
	private	Array!Component	_components;

	this(string name = null)
	{
		this.name = name;
	}

	~this()
	{
		foreach(component; _components)
		{
			component.destroy();
		}
	}

	T addComponent(T)() if(is(T : Component))
	{
		info("Adding ", T.stringof, " to ", name);

		auto component = ComponentFactory!T.build(this);
		component._owner = this;
		_components.insertBack(component);
		return component;
	}

	auto getComponents(T, AllowDerived derived = AllowDerived.no)()
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

	@property
	{
		string name() const
		{
			return _name.length ? _name : "Anonymous Entity";
		}

		void name(string name)
		{
			this._name = name;
		}
	}
}

abstract class Component
{
	private Entity _owner;

	private alias DestroyFunction = void function(Component);
	private DestroyFunction _destroy;
	private void destroy()
	{
		_destroy(this);
	}
}

alias AllowDerived = Flag!"AllowDerived";


auto @property dependency(AllowDerived allowDerived = AllowDerived.yes)
{
	return Dependency(allowDerived);
}

// Used for Components depending on another Component on the same Entity
struct Dependency
{
	AllowDerived allowDerived = AllowDerived.yes;
};
enum isDependency(T) = is(T == Dependency);


template RegisterComponent(T) if(is(T : Component))
{
	private alias Helper = ComponentFactory!T;
}

private template ComponentFactory(T) if(is(T : Component))
{
	private:
	T[] liveComponents;

	T build(Entity owner)
	{
		//TODO: Don´t use GC
		auto component = new T;
		component._destroy = &destroy;
		liveComponents ~= component;

		foreach(i, FT; typeof(T.tupleof))
		{
			import vibe.internal.meta.uda;
			enum uda = findFirstUDA!(Dependency, T.tupleof[i]);
			static if(uda.found)
			{
				trace("Resolving dependency ", T.stringof, ".", T.tupleof[i].stringof);
				component.tupleof[i] = owner.getOrAddComponent!(FT, __traits(getAttributes, T.tupleof[i])[uda.index].allowDerived);
			}
		}

		return component;
	}

	void destroy(Component component)
	{
		assert(component.classinfo == T.classinfo);

		import std.algorithm : countUntil;
		liveComponents[liveComponents.countUntil!"a is b"(component)] = liveComponents[$-1];
		liveComponents.length--;
	}

	static this()
	{
		import std.traits : isCallable;
		import std.algorithm : among;

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
}

private alias FrameUpdateDispatch = void function();
private FrameUpdateDispatch[] frameUpdateDispatchers;
package void dispatchFrameUpdate()
{
	foreach(dispatcher; frameUpdateDispatchers) dispatcher();
}