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

	//TODO: No need to go through Json. Serialize to and from dynamic array, works with Bson etc. too
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

struct StaticString
{
	enum MaxLength = 63;

	// Total size is 64 bytes, fits nicely in a cache line.
	private ubyte _length;
	char[MaxLength] data;

	inout(char)[] opSlice() inout
	{
		return data[0 .. length];
	}

	string toString() const
	{
		return this[].idup;
	}

	void opAssign(string str)
	{
		assert(str.length <= MaxLength);
		_length = cast(typeof(_length))str.length;
		this[][] = str[];
	}

	@property
	{
		ubyte length() const
		{
			return length;
		}
	}
}