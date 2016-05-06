module kratos.resource.manager;

import std.container : Array;
import std.conv : to;
import std.traits : isCallable, Parameters, ReturnType;
import std.typecons : RefCounted, refCounted, RefCountedAutoInitialize;

alias Handle(T) = RefCounted!(T, RefCountedAutoInitialize.no);

template Manager(ResourceType) if(is(ResourceType == class))
{
	alias Handle = .Handle!HandleImpl;
	
	private
	{
		ResourceType[] resources;
		Array!size_t freeSlotList;
	}
	
	private struct HandleImpl
	{
		const size_t slot = size_t.max;
		
		@disable this(this);
		
		this(size_t slot)
		{
			this.slot = slot;
		}
		
		~this()
		{
			destroy(resources[slot]);
			freeSlotList.insertBack(slot);
		}
	}
	
	Handle create(Args...)(Args args)
	{
		return add(new ResourceType(args));
	}
	
	Handle add(ResourceType resource)
	{
		auto handle = reserveSlot();
		resources[handle.slot] = resource;
		return handle;
	}
	
	ResourceType getConcreteResource()(auto ref Handle handle)
	{
		return resources[handle.slot];
	}
	
	void update(Handle handle, ResourceType replacement)
	{
		destroy(resources[handle.slot]);
		resources[handle.slot] = replacement;
	}
	
	private:
	
	Handle reserveSlot()
	{
		if(freeSlotList.empty)
		{
			resources.length++;
			return Handle(resources.length - 1);
		}
		else
		{
			return Handle(freeSlotList.removeAny());
		}
	}
}

template Loader(ResourceType, alias load, bool manageResource) if
(
	isCallable!(load) &&
	Parameters!load.length == 1 &&
	is(ReturnType!load : ResourceType)
)
{
	alias Identifier = Parameters!(load)[0];
	
	static if(manageResource)
	{
		private alias Manager = .Manager!ResourceType;
		alias StoredResource = Manager.Handle;
	}
	else
	{
		alias StoredResource = ResourceType;
	}
		
	private StoredResource[Identifier] loadedResources;
	
	StoredResource get(Identifier name)
	{
		if(auto resourcePtr = name in loadedResources)
		{
			return *resourcePtr;
		}
		else
		{
			static if(manageResource)
			{
				auto resource = Manager.add(load(name));
			}
			else
			{
				auto resource = load(name);
			}
			
			loadedResources[name] = resource;
			return resource;
		}
	}
	
	void purge()
	{
		foreach(key; loadedResources.keys)
		{
			auto resourcePtr = key in loadedResources;
			
			static if(manageResource)
			{
				//TODO: AAs used to have issues with RAII structs. Make sure refCount is as expected.
				auto canBeRemoved = resourcePtr.refCountedStore.refCount == 1;
			}
			else
			{
				enum canBeRemoved = true;
			}
			
			if(canBeRemoved)
			{
				destroy(*resourcePtr);
				loadedResources.remove(key);
			}
		}
	}
}