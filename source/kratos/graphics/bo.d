module kratos.graphics.bo;

import kratos.resource.resource;
import kratos.graphics.gl;
import kratos.graphics.shadervariable;

import std.experimental.logger;


struct VBO
{
	alias Buffer = BO!GL_ARRAY_BUFFER;

	private Buffer				_buffer;
	private size_t				_numVertices;
	private VertexAttributes	_attributes;

	alias buffer this;

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
		_buffer = bo!GL_ARRAY_BUFFER(data, dynamic);
		_numVertices = data.length / attributes.totalByteSize;
		_attributes = attributes;
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
		assert(dynamic, "Can't call getDynamic on non-dynamic buffers");
		assert(toVertexAttributes!T == attributes);
		return cast(T[])data;
	}
	
	auto getCustom(T)()
	{
		import std.algorithm.searching : all, canFind, countUntil;

		static immutable partialAttributes = toVertexAttributes!T;

		assert(partialAttributes[].all!(a => attributes[].canFind(a)));

		static struct Range
		{
			private const(void)[] buffer;
			private const size_t stride;
			private size_t[partialAttributes.count] offsets;
			
			T front()
			{
				T retVal;

				foreach(i, FT; typeof(T.tupleof))
				{
					retVal.tupleof[i] = *cast(FT*)(buffer.ptr + offsets[i]);
				}

				return retVal;
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

		auto retVal = Range(data, attributes.totalByteSize);

		foreach(i, ref offset; retVal.offsets)
		{
			auto idx = attributes[].countUntil(partialAttributes[i]);
			offset = attributes[0 .. idx].totalByteSize;
		}

		return retVal;
	}

	@property const
	{
		auto numVertices()
		{
			return _numVertices;
		}

		ref const(VertexAttributes) attributes()
		{
			return _attributes;
		}

		ref const(Buffer) buffer()
		{
			return _buffer;
		}
	}
}

enum IndexType : GLenum
{
	UShort	= GL_UNSIGNED_SHORT,
	UInt	= GL_UNSIGNED_INT
}

struct IBO
{
	alias Buffer = BO!GL_ELEMENT_ARRAY_BUFFER;

	private	Buffer		_buffer;
	private	GLint		_numIndices;
	private	IndexType	_indexType;

	alias buffer this;

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
		_buffer = bo!GL_ELEMENT_ARRAY_BUFFER(data, dynamic);
		_numIndices = cast(GLint)(data.length / indexSize[type]);
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


private alias BO(GLenum Target) = Handle!(BO_Impl!Target);

BO!Target bo(GLenum Target)(void[] data, bool dynamic)
{

	auto bo = BO!Target(cast(ubyte[])data, 0, dynamic);
	gl.GenBuffers(1, &bo.handle);
	info("Created Buffer Object ", bo.handle);

	unbindVAO();
	bo.bind();
	gl.BufferData(Target, data.length, data.ptr, dynamic ? GL_DYNAMIC_DRAW : GL_STATIC_DRAW);

	return bo;
}

private struct BO_Impl(GLenum Target)
{
	private	ubyte[]	data;
	private GLuint	handle;
	private	bool	dynamic;
	
	@disable this(this);

	~this()
	{
		gl.DeleteBuffers(1, &handle);
		info("Deleted Buffer Object ", handle);
	}
	
	void bind() const
	{
		trace("Binding Buffer Object ", handle);
		gl.BindBuffer(Target, handle);
	}

	void update() const
	{
		assert(dynamic);
		unbindVAO();
		bind();
		gl.BufferSubData(Target, 0, data.length, data.ptr);
	}
}

// Workaround for some strange DMD bug
private void unbindVAO()
{
	import kratos.graphics.vao;
	VAO.unbind();
}