module kratos.graphics.shadervariable;

import kratos.graphics.gl;
import kratos.graphics.texture;
import kratos.util : StaticString;

import std.variant;
import kgl3n.vector;
import kgl3n.matrix;

import std.conv : text;
import std.typetuple : TypeTuple, staticIndexOf;
import std.container : Array;
import std.experimental.logger;
import std.traits : Unqual;


immutable VertexAttributes toVertexAttributes(T) = toVertexAttributesImpl!T;

private auto toVertexAttributesImpl(T)()
{
	auto attributes = VertexAttributes(T.tupleof.length);

	foreach(i, FT; typeof(T.tupleof))
	{
		//TODO: Add support for static arrays
		attributes[][i] = VertexAttribute(GLType!FT, StaticString(T.tupleof[i].stringof));
	}

	return attributes;
}

struct VertexAttribute
{
	// Type of this vertex attribute as returned by get active attrib. For example, GL_FLOAT_VEC3
	GLenum			aggregateType;
	StaticString	name;

	@property const
	{
		// Basic type of this attribute as expected by vertex attrib pointer. For example, GL_FLOAT for GL_FLOAT_VEC3
		GLenum basicType()
		{
			return attributeBasicType[aggregateType];
		}

		// Size in basic type units of the aggregate type. For example, 3 for GL_FLOAT_VEC3
		GLsizei basicTypeSize()
		{
			return attributeTypeSize[aggregateType];
		}

		GLsizei byteSize()
		{
			return GLTypeSize[aggregateType];
		}
	}

	string toString() const
	{
		string aggregateTypeName;
		foreach(T; GLTypes)
		{
			if(T.glType == aggregateType) aggregateTypeName = T.nativeType.stringof;
		}

		//TODO: This idup should not be necessary. Probably fixed in 2.066
		return (aggregateTypeName ~ " " ~ name[]).idup;
	}

	static {
		VertexAttribute fromAggregateType(T)(string name)
		{
			return VertexAttribute(GLType!T, StaticString(name));
		}

		VertexAttribute fromBasicType(T)(size_t count, string name)
		{
			return VertexAttribute(attributeAggregateType[GLType!T][count], StaticString(name));
		}
	}
}

struct VertexAttributes
{
	enum GLsizei			Max = 16;

	VertexAttribute[Max]	attributes;
	GLsizei					count;

	this(GLsizei count)
	{
		assert(count <= Max);
		this.count = count;
	}

	inout(VertexAttribute[]) opSlice(size_t startIdx, size_t endIdx) inout
	{
		assert(startIdx <= endIdx);
		assert(endIdx <= count);
		return attributes[startIdx..endIdx];
	}

	inout(VertexAttribute[]) opSlice() inout
	{
		return this[0..count];
	}

	ref inout(VertexAttribute) opIndex(size_t index) inout
	{
		return this[][index];
	}

	void opIndexAssign(VertexAttribute attribute, size_t index)
	{
		this[][index] = attribute;
	}

	void add(VertexAttribute attribute)
	{
		assert(count < Max);
		attributes[count++] = attribute;
	}

	@property GLsizei totalByteSize() const
	{
		return this[].totalByteSize;
	}

	string toString() const
	{
		import std.string;
		return format("%s", this[]);
	}
}

@property GLsizei totalByteSize(const VertexAttribute[] attributes)
{
	import std.algorithm : reduce;
	return reduce!q{a + b.byteSize}(0, attributes);
}


// Uniform descriptor for a particular program. Combination of a Parameter and an offset in the storage buffer
struct Uniform
{
	GLenum		type;
	string		name;
	ptrdiff_t	offset;
	GLsizei		size;
	GLsizei		byteSize;
	
	bool isSampler() const
	{
		return type == GLType!TextureUnit;
	}
	
	bool isUser() const
	{
		return !isSampler;
	}
}

// Reference to an Uniform instance. Can be used to set the value of this Uniform
struct UniformRef(T)
{
	private	GLsizei	_size;
	private	T[]	store;

	void opAssign(UniformRef uniformRef)
	{
		_size = uniformRef._size;
		store = uniformRef.store;
	}

	void opAssign(Y)(auto ref Y value) if(is(Unqual!Y == T))
	{
		this[0] = value;
	}

	void opAssign(Y)(Y[] values) if(is(Unqual!Y == T))
	{
		foreach(i, ref value; values)
		{
			this[i] = value;
		}
	}

	void opIndexAssign(Y)(auto ref Y value, size_t index) if(is(Unqual!Y == T))
	{
		if(store == null)
		{
			return;
		}

		assert(index < size, "Uniform index out of bounds");
		store[index] = value;
	}

	private inout(void*) ptr() inout
	{
		return store.ptr;
	}

	@property const
	{
		GLsizei size() { return _size; }
	}
}

//TODO: Make package protected?
// Set of all uniforms for use with a Program, and Textures bound to sampler Uniforms.
struct Uniforms
{
	this(Uniform[] allUniforms)
	{
		import std.range : zip, iota, repeat, sequence;
		import std.algorithm : map, filter, reduce;
		import std.array : array, assocArray;
		import std.exception : assumeUnique;
		import std.typecons : tuple;

		this._allUniforms = allUniforms;

		//TODO: Use some per-program pool allocator?
		this._uniformData = new ubyte[reduce!q{a + b.byteSize}(0, allUniforms)];

		auto indexedUniforms = 
			allUniforms
			.zip(iota(uint.max));

		auto samplerUniforms =
			indexedUniforms
			.filter!(a => a[0].isSampler);

		_textureIndices = 
			samplerUniforms
			.zip(iota(uint.max))
			.map!(a => tuple(a[0][0].name, a[1]))
			.assocArray;

		foreach(uniform, ui, tu; zip(samplerUniforms, iota(TextureUnit.Size)))
		{
			toRef!TextureUnit(_allUniforms[ui]) = TextureUnit(tu);
		}

		_textures.insert(defaultTexture.repeat(_textureIndices.length));

		_userUniforms = 
			indexedUniforms
			.filter!(a => a[0].isUser)
			.map!(a => tuple(a[0].name, a[1]))
			.assocArray;

		_setters = _allUniforms.map!(a => uniformSetter[a.type]).array;

		_builtinUniforms = getRefs!BuiltinUniforms;
	}

	this(this)
	{
		trace("Duplicating Uniforms");
		_uniformData		= _uniformData.dup;
		_textures			= _textures.dup;
		_builtinUniforms	= getRefs!BuiltinUniforms;
	}

	private ubyte[]			_uniformData;
	private Array!Texture	_textures;
	private BuiltinUniforms _builtinUniforms;

	//Shared across instances for the same program
	private Uniform[]		_allUniforms;
	private uint[string]	_userUniforms;
	private uint[string]	_textureIndices;
	private UniformSetter[]	_setters;

	void opIndexAssign(ref Texture texture, string name)
	{
		if(auto indexPtr = name in _textureIndices)
		{
			_textures[*indexPtr] = texture;
		}
		else
		{
			warning("No such texture: " ~ name);
		}
	}

	void opIndexAssign(Texture texture, string name)
	{
		this[name] = texture;
	}

	void opIndexAssign(T)(auto ref T value, string name)
	{
		getRef!T(name) = value;
	}

	UniformRef!T getRef(T)(string name)
	{
		if(auto indexPtr = name in _userUniforms)
		{
			return toRef!T(_allUniforms[*indexPtr]);
		}
		else
		{
			return UniformRef!T(0, null);
		}
	}

	RefContainer getRefs(RefContainer)()
	{
		RefContainer container;
		foreach(i, ref field; container.tupleof)
		{
			static if(is(typeof(field) == UniformRef!T, T))
			{
				field = this.getRef!T(__traits(identifier, container.tupleof[i]));
			}
			else static assert(false, "Can only get refs when all fields are UniformRefs");

		}
		return container;
	}

	@property
	{
		BuiltinUniforms builtinUniforms()
		{
			return _builtinUniforms;
		}
	}

	package void apply(ref Uniforms newValues, ref Array!Sampler samplers)
	{
		//TODO: Ensure equivalent Uniforms passed
		foreach(i, uniform; _allUniforms)
		{
			auto currentValue	= _uniformData[uniform.offset .. uniform.offset + uniform.byteSize];
			auto newValue		= newValues._uniformData[uniform.offset .. uniform.offset + uniform.byteSize];
			if(currentValue != newValue)
			{
				_setters[i](i, uniform.size, newValue.ptr);
				currentValue[] = newValue[];
			}
		}

		import std.range : zip, iota;
		foreach(i, texture, sampler; zip(iota(TextureUnit.Size), newValues._textures[], samplers[]))
		{
			TextureUnit(i).set(texture, sampler);
			_textures[i] = texture;
		}
	}

	package @property auto textureCount() const
	{
		return _textures.length;
	}

	package @property auto allUniforms() const
	{
		return _allUniforms;
	}

	private UniformRef!T toRef(T)(Uniform uniform)
	{
		assert(GLType!T == uniform.type, "Uniform type mismatch: " ~ T.stringof);

		return UniformRef!T(
			uniform.size,
			cast(T[])(_uniformData[uniform.offset .. uniform.offset + uniform.byteSize])
		);
	}

	package void initializeSamplerIndices()
	{
		import std.algorithm : filter;
		foreach(i, uniform; allUniforms)
		{
			if(uniform.isSampler)
			{
				auto uniformRef = toRef!TextureUnit(uniform);
				_setters[i](i, uniformRef.size, uniformRef.ptr);
			}
		}
	}

	package uint* getSamplerIndex(string name)
	{
		return name in _textureIndices;
	}

	// Should be package(kratos)
	GLenum getGlType(string name)
	{
		if(auto indexPtr = name in _userUniforms)
		{
			return _allUniforms[*indexPtr].type;
		}
		else
		{
			return 0;
		}
	}

	package bool opEquals(const ref Uniforms other) const
	{
		import std.algorithm.comparison : equal;
		return
			_uniformData.equal(other._uniformData) &&
			_allUniforms.equal(other._allUniforms);
	}
}

struct BuiltinUniforms
{
	UniformRef!mat4 W;
	UniformRef!mat4 V;
	UniformRef!mat4 P;
	UniformRef!mat4 WV;
	UniformRef!mat4 VP;
	UniformRef!mat4 WVP;
}

/// TypeTuple of all types which can be used as shader uniforms
alias UniformTypes = TypeTuple!(
	float,
	vec2,
	vec3,
	vec4,
	
	int,
	vec2i,
	vec3i,
	vec4i,
	
	bool,
	
	mat2,
	mat3,
	mat4,

	TextureUnit
);

private alias UniformSetter = void function(GLint location, GLsizei size, void* data);
private UniformSetter[GLenum] uniformSetter;
static this()
{
	foreach(T; UniformTypes)
	{
		enum type = GLType!T;

		static if(is(T == float))
			uniformSetter[type] = (location, size, data) => gl.Uniform1fv(location, size, cast(float*)data);
		else static if(is(T == vec2))
			uniformSetter[type] = (location, size, data) => gl.Uniform2fv(location, size, cast(float*)data);
		else static if(is(T == vec3))
			uniformSetter[type] = (location, size, data) => gl.Uniform3fv(location, size, cast(float*)data);
		else static if(is(T == vec4))
			uniformSetter[type] = (location, size, data) => gl.Uniform4fv(location, size, cast(float*)data);

		else static if(is(T == int))
			uniformSetter[type] = (location, size, data) => gl.Uniform1iv(location, size, cast(int*)data);
		else static if(is(T == vec2i))
			uniformSetter[type] = (location, size, data) => gl.Uniform2iv(location, size, cast(int*)data);
		else static if(is(T == vec3i))
			uniformSetter[type] = (location, size, data) => gl.Uniform3iv(location, size, cast(int*)data);
		else static if(is(T == vec4i))
			uniformSetter[type] = (location, size, data) => gl.Uniform4iv(location, size, cast(int*)data);

		else static if(is(T == bool))
			uniformSetter[type] = (location, size, data) => gl.Uniform1iv(location, size, cast(int*)data);

		else static if(is(T == mat2))
			uniformSetter[type] = (location, size, data) => gl.UniformMatrix2fv(location, size, true, cast(float*)data);
		else static if(is(T == mat3))
			uniformSetter[type] = (location, size, data) => gl.UniformMatrix3fv(location, size, true, cast(float*)data);
		else static if(is(T == mat4))
			uniformSetter[type] = (location, size, data) => gl.UniformMatrix4fv(location, size, true, cast(float*)data);

		else static if(is(T == TextureUnit))
		{
			uniformSetter[type] = (location, size, data) 
			{
				info("Assigning Texture Unit", location, " - ", *cast(int*)data);
				gl.Uniform1iv(location, size, cast(int*)data);
			};
		}

		else static assert(false, "No uniform setter implemented for " ~ T.stringof);
	}
}


private void[][GLenum] defaultUniformValue;
static this()
{
	foreach(T; UniformTypes)
	{
		enum type = GLType!T;

		static if(is(T == float))
		{
			defaultUniformValue[type] = [0f];
		}
		else
		{
			defaultUniformValue[type] = [T.init];
		}
	}
}

private immutable GLenum[GLenum]			attributeBasicType;
private immutable GLint[GLenum]				attributeTypeSize;
private immutable GLenum[size_t][GLenum]	attributeAggregateType;

static this()
{
	attributeBasicType = [
		GL_FLOAT: GL_FLOAT,
		GL_FLOAT_VEC2: GL_FLOAT,
		GL_FLOAT_VEC3: GL_FLOAT,
		GL_FLOAT_VEC4: GL_FLOAT,
		
		GL_INT: GL_INT,
		GL_INT_VEC2: GL_INT,
		GL_INT_VEC3: GL_INT,
		GL_INT_VEC4: GL_INT,
		
		GL_BOOL: GL_BOOL,
	];

	attributeTypeSize = [
		GL_FLOAT: 1,
		GL_FLOAT_VEC2: 2,
		GL_FLOAT_VEC3: 3,
		GL_FLOAT_VEC4: 4,
		
		GL_INT: 1,
		GL_INT_VEC2: 2,
		GL_INT_VEC3: 3,
		GL_INT_VEC4: 4,
		
		GL_BOOL: 1,
	];

	attributeAggregateType = [
		GL_FLOAT: [
			1: GL_FLOAT,
			2: GL_FLOAT_VEC2,
			3: GL_FLOAT_VEC3,
			4: GL_FLOAT_VEC4
		],

		GL_INT: [
			1: GL_INT,
			2: GL_INT_VEC2,
			3: GL_INT_VEC3,
			4: GL_INT_VEC4
		],

		GL_BOOL: [
			1: GL_BOOL
		]
	];
}