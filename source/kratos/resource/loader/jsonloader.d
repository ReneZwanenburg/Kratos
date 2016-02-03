module kratos.resource.loader.jsonloader;

import kratos.resource.filesystem;
import kratos.resource.resource;

import kvibe.data.json : Json, parseJsonString;

/// Uncached JSON loader. The idea is that the resource reprsented by
/// the JSON document will be cached, so there's no need to cache the
/// document itself
Json loadJson(ResourceIdentifier name)
{
	return activeFileSystem.get!char(name).parseJsonString();
}