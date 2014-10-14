module kratos.resource.exporter.sceneexporter;

import kratos.scene;
import kratos.resource.resource;
import vibe.data.json;
import std.file;
import std.path;

void exportScene(Scene scene, ResourceIdentifier name)
{
	auto json = Json.emptyObject;
	json["name"] = scene.name;
	json["entities"] = Json.emptyArray;

	foreach(entity; scene.entities)
	{
		json["entities"] ~= serializeToJson(entity);
	}

	mkdirRecurse(name.dirName);
	write(name, json.toPrettyString());
}