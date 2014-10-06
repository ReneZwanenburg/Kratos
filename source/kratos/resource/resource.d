module kratos.resource.resource;

import std.typecons : RefCounted, RefCountedAutoInitialize;

/// Base type for resources which require deterministic destruction.
// TODO: Add support for weak references
alias Handle(T) = RefCounted!(T, RefCountedAutoInitialize.no);

/// Creates a Handle with initialized payload
auto initialized(T)() if(is(T == RefCounted!S, S...))
{
	T refCounted;
	refCounted.refCountedStore.ensureInitialized();
	return refCounted;
}

alias ResourceIdentifier = string;
