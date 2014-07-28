module kratos.resource.cache;

import std.container : Array;
import kratos.resource.resource;

template Cache(T, I)
//if(is(T == Handle!R, R)) //TODO re-enable contraint. DMD bug, fixed in 2.066
{
	alias Identifier = I;

	private struct Element
	{
		// Identifier strings will most likely have long equal prefixes. Use hash as fast initial test.
		size_t hash;
		Identifier id;
		T resource;
	}

	// TODO use hash map. Builtins are buggy, dcollections HashMap doesn't provide deterministic destruction.
	private Array!Element resources;

	static this()
	{

	}

	private size_t hashId(Identifier id)
	{
		return typeid(Identifier).getHash(&id);
	}

	private ptrdiff_t index(Identifier id)
	{
		import std.algorithm : countUntil;
		import std.typecons : tuple;

		return 
			resources[].countUntil!(
				(a, b) => a.hash == b[0] && a.id == b[1]
			)(tuple(id.hashId, id));
	}

	alias opIndex = get;

 	T get(alias create)(Identifier id)
	{
		const idx = id.index;
		if(idx == -1)
		{
			return put(id, create(id));
		}

		return resources[idx].resource;
	}

	T put(Identifier id, T resource)
	{
		assert(id.index == -1);

		resources.insert(Element(id.hashId, id, resource));
		return resource;
	}

	void purge()
	{
		size_t writeIndex = 0;
		foreach(i; 0..resources.length)
		{
			auto element = resources[i];
			if(element.resource.refCountedStore.refCount > 2)
			{
				resources[writeIndex++] = element;
			}
		}

		resources.removeBack(resources.length - writeIndex);
	}

}

unittest
{
	static struct _S
	{
		static size_t counter;

		@disable this(this);

		~this()
		{
			--counter;
		}
	}
	alias S = Handle!_S;
	static S s() {
		++S.counter;
		return initialized!S();
	}

	alias SCache = Cache!(S, int);

	assert(S.counter == 0);

	{
		auto s1 = SCache.put(0, s());
		assert(S.counter == 1);
		SCache.put(1, s());
		assert(S.counter == 2);
		SCache.purge();
		assert(S.counter == 1);
	}

	SCache.purge();
	assert(S.counter == 0);
}
