module kratos.graphics.shadervariable;

import kratos.graphics.gl;
import kratos.graphics.texture;

import std.variant;
import gl3n.linalg;

import std.conv : text;
import std.typetuple : TypeTuple, staticIndexOf;
import std.container : Array;
import std.logger;


// Parameter specification. Name, type, and size. No specific value
struct ShaderParameter
{
	GLint	size; // Size in 'type' units, not byte size
	GLenum	type;
	string	name;

	@property
	{
		GLsizei byteSize() const pure nothrow
		{
			return size * GLTypeSize[type];
		}

		GLenum backingType() const pure nothrow
		{
			return .backingType[type];
		}

		GLint backingTypeSize() const pure nothrow
		{
			return .backingTypeSize[type];
		}

		bool isSampler() const
		{
			return type == GLType!TextureUnit;
		}
		
		bool isBuiltin() const
		{
			//TODO: Implement builtins
			return false;
		}
		
		bool isUser() const
		{
			return !(isSampler || isBuiltin);
		}
	}
}

GLsizei totalByteSize(const ShaderParameter[] parameters)
{
	import std.algorithm : reduce;
	return reduce!q{a + b.byteSize}(0, parameters);
}


// Uniform descriptor for a particular program. Combination of a Parameter and an offset in the storage buffer
struct Uniform
{
	const	ShaderParameter	parameter;
	const	ptrdiff_t		offset;
	const	size_t			byteSize;

	alias parameter this;
}

// Reference to an Uniform instance. Can be used to set the value of this Uniform
struct UniformRef
{
	const	ShaderParameter	parameter;
	private	void[]			store;

	alias parameter this;

	auto opAssign(T)(auto ref T value)
	{
		this[0] = value;
	}

	auto opAssign(T)(T[] values)
	{
		foreach(i, ref value; values)
		{
			this[i] = value;
		}
	}

	auto opIndexAssign(T)(auto ref T value, size_t index)
	{
		assert(GLType!T == type, "Uniform type mismatch: " ~ T.stringof);
		assert(index < size, "Uniform index out of bounds");
		(cast(T[])store)[index] = value;
		return this;
	}

	private inout(void*) ptr() inout
	{
		return store.ptr;
	}
}

//TODO: Make package protected?
// Set of all uniforms for use with a Program, and Textures bound to sampler Uniforms.
struct Uniforms
{
	this(ShaderParameter[] parameters)
	{
		import std.range : zip, iota, repeat, sequence;
		import std.algorithm : map, filter;
		import std.array : array, assocArray;
		import std.exception : assumeUnique;
		import std.typecons : tuple;

		this._allUniforms = 
			parameters
			.zip(iota(parameters.length))
			.map!(a => Uniform(a[0], parameters[0..a[1]].totalByteSize, a[0].byteSize))
			.array
			.assumeUnique;

		//TODO: Use some per-program pool allocator?
		this._uniformData = new ubyte[parameters.totalByteSize];

		auto indexedParameters = 
			parameters
			.zip(iota(uint.max));

		_builtinUniforms =
			indexedParameters
			.filter!(a => a[0].isBuiltin)
			.map!(a => a[1])
			.array
			.assumeUnique;

		auto samplerUniforms =
			indexedParameters
			.filter!(a => a[0].isSampler);

		{ // TODO: remove those temporaries, should not be neccesary in 2.066
			auto tmpTextureIndices = 
				samplerUniforms
				.zip(iota(uint.max))
				.map!(a => tuple(a[0][0].name, a[1]))
				.assocArray;
			_textureIndices = tmpTextureIndices.assumeUnique;
		}

		foreach(parameter, ui, tu; zip(samplerUniforms, iota(TextureUnit.Size)))
		{
			toRef(_allUniforms[ui]) = TextureUnit(tu);
		}

		_textures.insert(defaultTexture.repeat(_textureIndices.length));

		{
			auto tmpUserUniforms = 
				indexedParameters
				.filter!(a => a[0].isUser)
				.map!(a => tuple(a[0].name, a[1]))
				.assocArray;
			_userUniforms = tmpUserUniforms.assumeUnique;
		}

		_setters = _allUniforms.map!(a => uniformSetter[a.type]).array;
	}

	this(this)
	{
		trace("Duplicating Uniforms");
		_uniformData	= _uniformData.dup;
		_textures		= _textures.dup;
	}

	private ubyte[]						_uniformData;
	private Array!Texture				_textures;
	private immutable Uniform[]			_allUniforms;
	private immutable uint[]			_builtinUniforms;
	private immutable uint[string]		_userUniforms;
	private immutable uint[string]		_textureIndices;
	private immutable UniformSetter[]	_setters;

	void opIndexAssign(ref Texture texture, string name)
	{
		_textures[_textureIndices[name]] = texture;
	}

	void opIndexAssign(Texture texture, string name)
	{
		this[name] = texture;
	}

	void opIndexAssign(T)(auto ref T value, string name)
	{
		auto uRef = this[name];
		uRef = value;
	}

	UniformRef opIndex(string name)
	{
		return toRef(_allUniforms[_userUniforms[name]]);
	}

	package void apply(ref Uniforms newValues, ref Array!Sampler samplers)
	{
		//TODO: Ensure equivalent Uniforms passed
		foreach(i, uniform; _allUniforms)
		{
			auto currentValue	= toRef(uniform);
			auto newValue		= newValues.toRef(uniform);
			if(currentValue.store != newValue.store)
			{
				_setters[i](i, newValue);
				currentValue.store[] = newValue.store[];
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

	private UniformRef toRef(Uniform uniform)
	{
		return UniformRef(
			uniform.parameter,
			_uniformData[uniform.offset .. uniform.offset + uniform.byteSize]
		);
	}
}

/// TypeTuple of all types which can be used as shader uniforms and attributes
alias ShaderParameterTypes = TypeTuple!(
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

private alias UniformSetter = void function(GLint location, ref const UniformRef uniform);
private immutable UniformSetter[GLenum] uniformSetter;
static this()
{
	foreach(T; ShaderParameterTypes)
	{
		enum type = GLType!T;

		static if(is(T == float))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform1fv(location, uniform.parameter.size, cast(float*)uniform.ptr);
		else static if(is(T == vec2))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform2fv(location, uniform.parameter.size, cast(float*)uniform.ptr);
		else static if(is(T == vec3))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform3fv(location, uniform.parameter.size, cast(float*)uniform.ptr);
		else static if(is(T == vec4))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform4fv(location, uniform.parameter.size, cast(float*)uniform.ptr);

		else static if(is(T == int))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform1iv(location, uniform.parameter.size, cast(int*)uniform.ptr);
		else static if(is(T == vec2i))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform2iv(location, uniform.parameter.size, cast(int*)uniform.ptr);
		else static if(is(T == vec3i))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform3iv(location, uniform.parameter.size, cast(int*)uniform.ptr);
		else static if(is(T == vec4i))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform4iv(location, uniform.parameter.size, cast(int*)uniform.ptr);

		else static if(is(T == bool))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform1iv(location, uniform.parameter.size, cast(int*)uniform.ptr);

		else static if(is(T == mat2))
			uniformSetter[type] = (location, ref uniform) => gl.UniformMatrix2fv(location, uniform.parameter.size, false, cast(float*)uniform.ptr);
		else static if(is(T == mat3))
			uniformSetter[type] = (location, ref uniform) => gl.UniformMatrix3fv(location, uniform.parameter.size, false, cast(float*)uniform.ptr);
		else static if(is(T == mat4))
			uniformSetter[type] = (location, ref uniform) => gl.UniformMatrix4fv(location, uniform.parameter.size, false, cast(float*)uniform.ptr);

		else static if(is(T == TextureUnit))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform1iv(location, uniform.parameter.size, cast(int*)uniform.ptr);

		else static assert(false, "No uniform setter implemented for " ~ T.stringof);
	}
}


private void[][GLenum] defaultUniformValue;
static this()
{
	foreach(T; ShaderParameterTypes)
	{
		enum type = GLType!T;

		static if(is(T == float))
		{
			defaultUniformValue[type] = [0f];
		}
		else static if(is(T == Vector!(float, P), P...))
		{
			defaultUniformValue[type] = [T(0)];
		}
		else static if(is(T == Matrix!(float, P), P...))
		{
			defaultUniformValue[type] = [T.identity];
		}
		else
		{
			defaultUniformValue[type] = [T.init];
		}
	}
}

private immutable GLenum[GLenum] backingType;
private immutable GLint[GLenum] backingTypeSize;

static this()
{
	backingType = [
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

	backingTypeSize = [
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
}