module kratos.util;

import std.container : Array;

struct Event(Args...)
{
	@disable this(this);

	alias CallbackType = void delegate(Args);

	private Array!CallbackType callbacks;

	void raise(Args args)
	{
		foreach(callback; callbacks[]) callback(args);
	}
	
	void opOpAssign(string op)(CallbackType callback) if(op == "+")
	{
		callbacks.insertBack(callback);
	}
	
	void opOpAssign(string op)(CallbackType callback) if(op == "-")
	{
		import std.algorithm.searching : find;
		import std.range : take;
		callbacks.linearRemove(callbacks[].find(callback).take(1));
	}
}

public T staticCast(T, U)(U obj) if(is(T == class) && is(U == class))
{
	debug return cast(T)obj;
	else return cast(T)cast(void*)obj;
}

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
	ubyte length;
	char[MaxLength] data;

	this(string str)
	{
		this = str;
	}

	inout(char)[] opSlice() inout nothrow
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
		length = cast(typeof(length))str.length;
		this[][] = str[];
	}

	bool opEquals(const ref StaticString other) const
	{
		return this[] == other[];
	}

	hash_t toHash() const nothrow @trusted
	{
		auto slice = this[];
		return typeid(slice).getHash(&slice);
	}
}

T readFront(T)(ref inout(void)[] buffer)
{
	assert(buffer.length >= T.sizeof);
	auto value = (cast(const(T)[])buffer[0 .. T.sizeof])[0];
	buffer = buffer[T.sizeof .. $];
	return value;
}