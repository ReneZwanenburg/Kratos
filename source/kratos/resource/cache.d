module kratos.resource.cache;

import std.container : Array;
import std.typecons : RefCounted, RefCountedAutoInitialize;

template Cache(T, I)
{
	alias ResourceType = T;
	alias Identifier = I;
	alias Handle = RefCounted!(ResourceType, RefCountedAutoInitialize.no);

	private struct Element
	{
		// Identifier strings will most likely have long equal prefixes. Use hash as fast initial test.
		size_t hash;
		Identifier id;
		Handle resource;
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

	Handle get(Identifier id)
	{
		const idx = id.index;
		if(idx == -1) assert(0);

		return resources[idx].resource;
	}

	Handle put(Identifier id, Handle resource)
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
	static struct S
	{
		static size_t counter;

		~this()
		{
			--counter;
		}

		static opCall()
		{
			++counter;
			return S.init;
		}
	}

	alias SCache = Cache!(S, int);

	assert(S.counter == 0);

	{
		auto s = SCache.put(0, SCache.Handle());
		assert(S.counter == 1);
		SCache.put(1, SCache.Handle());
		assert(S.counter == 2);
		SCache.purge();
		assert(S.counter == 1);
	}

	SCache.purge();
	assert(S.counter == 0);
}
