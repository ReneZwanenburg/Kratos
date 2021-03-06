﻿module kratos.util;

import std.container : Array;

struct Event(Args...)
{
	@disable this(this);

	alias CallbackType = void delegate(Args);
	alias RegistrationType = EventRegistration!(typeof(this));

	private Array!CallbackType callbacks;

	void raise(Args args)
	{
		foreach(callback; callbacks[]) callback(args);
	}

	void raiseIf(bool condition, Args args)
	{
		if(condition)
		{
			raise(args);
		}
	}
	
	void opOpAssign(string op)(CallbackType callback) if(op == "+")
	{
		callbacks.insertBack(callback);
	}
	
	void opOpAssign(string op)(CallbackType callback) if(op == "-")
	{
		linearRemove(callbacks, callback);
	}

	RegistrationType register(CallbackType callback)
	{
		this += callback;
		return RegistrationType(&this, callback);
	}
}

struct EventRegistration(EventType)
{
	alias CallbackType = EventType.CallbackType;
	private EventType* event;
	private CallbackType callback;

	@disable this(this);

	this(EventType* event, CallbackType callback)
	{
		this.event = event;
		this.callback = callback;
	}

	~this()
	{
		if(event == null) return;
		*event -= callback;
	}

	public void opAssign(EventRegistration other)
	{
		import std.algorithm.mutation : swap;
		swap(this, other);
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

void linearRemoveAt(T)(ref Array!T array, size_t index)
{
	array.linearRemove(array[index .. index + 1]);
}

void unstableRemoveAt(T)(ref T[] array, size_t index)
{
	import std.algorithm.mutation : remove, SwapStrategy;
	array = array.remove!(SwapStrategy.unstable)(index);
}

void linearRemove(T, U)(ref Array!T array, auto ref U element)
if(is(T : U) || is(U : T))
{
	import std.algorithm.searching : countUntil;
	array.linearRemoveAt(array[].countUntil(element));
}

void unstableRemove(T)(ref T[] array, auto ref T element)
{
	import std.algorithm.searching : countUntil;
	array.unstableRemoveAt(array.countUntil(element));
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

struct RawFileWriter
{
	import std.stdio : File;

	private File file;

	@disable this();
	@disable this(this);

	this(File file)
	{
		this.file = file;
	}

	void put(T)(auto ref T value) if(!is(T == U[], U))
	{
		put((&value)[0 .. 1]);
	}

	void put(T)(T[] values)
	{
		file.rawWrite(values);
	}
}

T getOrAdd(AA : T[K], T, K)(ref AA aa, K key, scope lazy T createT)
{
	if(auto tPtr = key in aa)
	{
		return *tPtr;
	}
	else
	{
		auto t = createT;
		aa[key] = t;
		return t;
	}
}