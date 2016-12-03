module kratos.resource.mesh;

import kratos.graphics.gl;
import kratos.graphics.shadervariable;


struct VertexBuffer
{
	private void[]				_buffer;
	private size_t				_length;
	private size_t				_vertexSize; // Cached _attributes.totalByteSize
	private VertexAttributes	_attributes;
	private bool				_dynamic;

	this(T)(T[] data, bool dynamic = false)
	{
		this(data, toVertexAttributes!T, dynamic);
	}

	this(const(void)[] data, VertexAttributes attributes)
	{
		this(cast(void[])data, attributes, false);
	}

	this(void[] data, VertexAttributes attributes, bool dynamic = false)
	{
		_buffer = data;
		_vertexSize = attributes.totalByteSize;
		_length = data.length / _vertexSize;
		_attributes = attributes;
		_dynamic = dynamic;
	}

	const(T[]) get(T)() const
	{
		static if(!is(T == void))
		{
			assert(toVertexAttributes!T == attributes);
		}
		return cast(T[])data;
	}

	T[] getDynamic(T)()
	{
		assert(_dynamic, "Can't call getDynamic on non-dynamic buffers");
		assert(toVertexAttributes!T == attributes);
		return cast(T[])data;
	}
	
	auto getCustom(T, bool dynamic = false)()
	{
		import std.algorithm.searching : countUntil;
		alias View = VertexBufferView!(T, dynamic);

		assert(isValidCustomFormat!T);

		auto retVal = View(_buffer, _vertexSize);

		foreach(i, ref offset; retVal.offsets)
		{
			auto idx = attributes[].countUntil(View.attributes[i]);
			offset = attributes[0 .. idx].totalByteSize;
		}

		return retVal;
	}

	bool isValidCustomFormat(T)() const
	{
		import std.algorithm.searching : all, canFind;
		static immutable partialAttributes = toVertexAttributes!T;
		return partialAttributes[].all!(a => attributes[].canFind(a));
	}

	@property const
	{
		auto length()
		{
			return _length;
		}

		ref const(VertexAttributes) attributes()
		{
			return _attributes;
		}
	}
}

private struct VertexBufferView(T, bool dynamic)
{
	private static immutable attributes = toVertexAttributes!T;
		
	private static struct FrontType
	{
		static if(dynamic)
		{
			private void*[attributes.count] attribPointers;
		}
		else
		{
			private const(void)*[attributes.count] attribPointers;
		}
		
		alias value this;
		
		@property
		{
			T value()
			{
				T retVal;

				foreach(i, FT; typeof(T.tupleof))
				{
					retVal.tupleof[i] = *cast(FT*)(attribPointers[i]);
				}

				return retVal;
			}
			
			static if(dynamic)
			{
				void value(T newValue)
				{
					foreach(i, FT; typeof(T.tupleof))
					{
						*cast(FT*)(attribPointers[i]) = retVal.tupleof[i];
					}
				}
			}
		}
	}
	
	static if(dynamic)
	{
		private void[] buffer;
	}
	else
	{
		private const(void)[] buffer;
	}
	
	private const size_t stride;
	private size_t[attributes.count] offsets;
	
	FrontType front()
	{
		typeof(FrontType.attribPointers) pointers;
		
		foreach(i; 0..pointers.length)
		{
			pointers[i] = buffer.ptr + offsets[i];
		}
	
		return FrontType(pointers);
	}
	
	bool empty()
	{
		return buffer.length == 0;
	}
	
	void popFront()
	{
		buffer = buffer[stride .. $];
	}
}

enum IndexType : GLenum
{
	UShort	= GL_UNSIGNED_SHORT,
	UInt	= GL_UNSIGNED_INT
}

struct IndexBuffer
{
	private	void[]		_buffer;
	private	GLint		_numIndices;
	private	IndexType	_indexType;

	this(uint[] data, bool dynamic = false)
	{
		this(data, IndexType.UInt, dynamic);
	}

	this(ushort[] data, bool dynamic = false)
	{
		this(data, IndexType.UShort, dynamic);
	}

	this(const(void)[] data, IndexType indexType)
	{
		this(cast(void[])data, indexType, false);
	}

	this(void[] data, IndexType type, bool dynamic = false)
	{
		_buffer = data;
		import std.conv : to;
		_numIndices = to!GLint(data.length / indexSize[type]);
		_indexType = type;
	}

	const(T[]) get(T)() const
	{
		static if(is(T == uint))
		{
			assert(_indexType == IndexType.UInt);
		}
		else static if(is(T == ushort))
		{
			assert(_indexType == IndexType.UShort);
		}
		else static assert(is(T == void));

		return cast(T[])data;
	}
	
	T[] getDynamic(T)()
	{
		assert(dynamic, "Can't call getDynamic on non-dynamic buffers");
		static if(is(T == uint))
		{
			assert(_indexType == IndexType.UInt);
		}
		else static if(is(T == ushort))
		{
			assert(_indexType == IndexType.UShort);
		}
		else static assert(false);
		
		return cast(T[])data;
	}

	@property const
	{
		auto numIndices()
		{
			return _numIndices;
		}

		auto indexType()
		{
			return _indexType;
		}

		auto buffer()
		{
			return _buffer;
		}
	}
}

private immutable size_t[GLenum] indexSize;
static this()
{
	indexSize = [
		IndexType.UShort:	ushort.sizeof,
		IndexType.UInt:		uint.sizeof
	];
}

