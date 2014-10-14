module kratos.util;

import std.container : Array;

//TODO move to a more appropriate place
auto backInserter(T)(ref Array!T array)
{
	static struct Inserter
	{
		private Array!T* array;
		
		void put()(auto ref T elem)
		{
			array.insertBack(elem);
		}
	}
	
	return Inserter(&array);
}

struct SerializableArray(T)
{
	Array!T backingArray;
	alias backingArray this;

	import vibe.data.json;
	Json toRepresentation()
	{
		auto json = Json.emptyArray;
		foreach(ref element; backingArray)
		{
			json.appendArrayElement(serializeToJson(element));
		}
		return json;
	}

	static SerializableArray!T fromRepresentation(Json json)
	{
		assert(json.type == Json.Type.array);
		SerializableArray!T array;
		array.reserve(json.length);
		import std.algorithm : map;
		import std.range : put;
		auto inserter = array.backingArray.backInserter;
		put(inserter, json[].map!(a => a.deserializeJson!T));
		return array;
	}
}