module kratos.resource.loader.jsonloader;

import kratos.resource.filesystem;

import vibe.data.json : Json, parseJsonString;

/// Uncached JSON loader. The idea is that the resource reprsented by
/// the JSON document will be cached, so there's no need to cache the
/// document itself
Json loadJson(string name)
{
	return activeFileSystem.get(name).asText.parseJsonString();
}