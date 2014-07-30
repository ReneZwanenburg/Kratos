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

// Value storage struct for an Uniform
package struct UniformValue
{
	this(T)(T val)
	{
		import std.conv : text;
		mixin("_" ~ staticIndexOf!(T, ShaderParameterTypes).text ~ " = val;");
	}

	union
	{
		mixin(uniformValueMembers);
	}
}

// Actual Uniform instance. Combination of a Parameter and a value to pass to that parameter
struct Uniform
{
	const	ShaderParameter	parameter;
			UniformValue	value;

	alias parameter this;

	@disable this();

	this(ShaderParameter parameter)
	{
		this.parameter = parameter;
		this.value = defaultUniformValue[parameter.type];
	}

	ref auto opAssign(T)(auto ref T value)
	{
		assert(GLType!T == parameter.type, "Uniform type mismatch: " ~ T.stringof);
		this.value = UniformValue(value);
		return this;
	}

	ref auto opAssign(T)(auto ref T[] values)
	{
		static assert(false, "Uniform arrays not implemented yet");

		assert(GLType!T == parameter.type, "Uniform type mismatch: " ~ T.stringof);
		assert(values.length <= parameter.size, 
		       "Uniform array length = " ~ parameter.size.text ~ 
		       ", provided array length = " ~ values.length.text);
		// TODO store values
		return this;
	}
}

//TODO: Make package protected?
// Set of all uniforms for use with a Program, and Textures bound to sampler Uniforms.
struct Uniforms
{

	//TODO: Perhaps a Uniform backing store can be put in here

	this(ShaderParameter[] parameters)
	{
		import std.range : zip, iota, repeat;
		import std.algorithm : map, filter;
		import std.array : array, assocArray;
		import std.exception : assumeUnique;
		import std.typecons : tuple;

		this._allUniforms = parameters.map!Uniform.array;

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
			_allUniforms[ui] = TextureUnit(tu);
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
		_allUniforms	= _allUniforms.dup;
		_textures		= _textures.dup;
	}

	private Uniform[]					_allUniforms;
	private Array!Texture				_textures;
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
		_allUniforms[_userUniforms[name]] = value;
	}

	Uniform* opIndex(string name)
	{
		return &_allUniforms[_userUniforms[name]];
	}

	package void apply(ref Uniforms newValues, ref Array!Sampler samplers)
	{
		//TODO: Ensure equivalent Uniforms passed
		foreach(i, ref newVal; newValues._allUniforms)
		{
			if(_allUniforms[i].value !is newVal.value)
			{
				_setters[i](i, newVal);
				_allUniforms[i].value = newVal.value;
			}
		}

		import std.range : zip, iota;
		foreach(i, texture, sampler; zip(iota(TextureUnit.Size), newValues._textures[], samplers[]))
		{
			TextureUnit(i).set(texture, sampler);
			_textures[i] = texture;
		}
	}

	package auto textures() const
	{
		return _textures;
	}

	package auto allUniforms() const
	{
		return _allUniforms;
	}
}

// Generator for UniformValue union members
private string uniformValueMembers()
{
	string retVal;

	foreach(i, T; ShaderParameterTypes)
	{
		import std.conv : text;
		retVal ~= T.stringof ~ " _" ~ i.text ~ ";";
	}

	return retVal;
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

private alias UniformSetter = void function(GLint location, ref const Uniform uniform);
private immutable UniformSetter[GLenum] uniformSetter;
static this()
{
	foreach(T; ShaderParameterTypes)
	{
		enum type = GLType!T;

		static if(is(T == float))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform1fv(location, uniform.parameter.size, cast(float*)&uniform.value);
		else static if(is(T == vec2))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform2fv(location, uniform.parameter.size, cast(float*)&uniform.value);
		else static if(is(T == vec3))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform3fv(location, uniform.parameter.size, cast(float*)&uniform.value);
		else static if(is(T == vec4))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform4fv(location, uniform.parameter.size, cast(float*)&uniform.value);

		else static if(is(T == int))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform1iv(location, uniform.parameter.size, cast(int*)&uniform.value);
		else static if(is(T == vec2i))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform2iv(location, uniform.parameter.size, cast(int*)&uniform.value);
		else static if(is(T == vec3i))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform3iv(location, uniform.parameter.size, cast(int*)&uniform.value);
		else static if(is(T == vec4i))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform4iv(location, uniform.parameter.size, cast(int*)&uniform.value);

		else static if(is(T == bool))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform1iv(location, uniform.parameter.size, cast(int*)&uniform.value);

		else static if(is(T == mat2))
			uniformSetter[type] = (location, ref uniform) => gl.UniformMatrix2fv(location, uniform.parameter.size, false, cast(float*)&uniform.value);
		else static if(is(T == mat3))
			uniformSetter[type] = (location, ref uniform) => gl.UniformMatrix3fv(location, uniform.parameter.size, false, cast(float*)&uniform.value);
		else static if(is(T == mat4))
			uniformSetter[type] = (location, ref uniform) => gl.UniformMatrix4fv(location, uniform.parameter.size, false, cast(float*)&uniform.value);

		else static if(is(T == TextureUnit))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform1iv(location, uniform.parameter.size, cast(int*)&uniform.value);

		else static assert(false, "No uniform setter implemented for " ~ T.stringof);
	}
}


private UniformValue[GLenum] defaultUniformValue;
static this()
{
	foreach(T; ShaderParameterTypes)
	{
		enum type = GLType!T;

		static if(is(T == float))
		{
			defaultUniformValue[type] = UniformValue(0f);
		}
		else static if(is(T == Vector!(float, P), P...))
		{
			defaultUniformValue[type] = UniformValue(T(0));
		}
		else static if(is(T == Matrix!(float, P), P...))
		{
			defaultUniformValue[type] = UniformValue(T.identity);
		}
		else
		{
			defaultUniformValue[type] = UniformValue(T.init);
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