module kratos.resource.resource;

import std.typecons : RefCounted, RefCountedAutoInitialize;

alias Handle(T) = RefCounted!(T, RefCountedAutoInitialize.no);