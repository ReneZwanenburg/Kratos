module kratos.resource.loader.internal;

public import kratos.resource.filesystem;

import vibe.data.json : Json, parseJsonString;

package:

/// Uncached JSON loader. The idea is that the resource reprsented by
/// the JSON document will be cached, so there's no need to cache the
/// document itself
Json loadJson(ResourceIdentifier name)
{
	return activeFileSystem.get!char(name).parseJsonString();
}

@property auto lowerCaseExtension(string path)
{
	import std.path : extension;
	import std.string : toLower;
	return path.extension.toLower();
}