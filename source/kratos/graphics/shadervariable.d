﻿module kratos.graphics.shadervariable;

import kratos.graphics.gl;
import kratos.graphics.texture;

import std.variant;
import gl3n.linalg;

import std.conv : text;
import std.typetuple : TypeTuple, staticIndexOf;


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

	@property
	{
		package ref const(UniformValue) valueStore() const
		{
			return value;
		}
		
		package void valueStore(ref const UniformValue value)
		{
			this.value = value;
		}
	}
}


struct Uniforms
{
	//TODO: Perhaps a Uniform backing store can be put in here

	@disable this();

	this(Uniform[] allUniforms)
	{
		this._allUniforms = allUniforms.dup;

		import std.range;
		import std.algorithm;
		import std.array;
		import std.exception;
		import std.typecons;

		auto indexedUniforms = _allUniforms.map!(a => a.parameter).zip(iota(uint.max));

		_builtinUniforms =
			indexedUniforms
			.filter!(a => a[0].isBuiltin)
			.map!(a => a[1])
			.array
			.assumeUnique;

		auto samplerUniforms =
			indexedUniforms
			.filter!(a => a[0].isSampler);

		foreach(parameter, ui, tu; zip(samplerUniforms, iota(TextureUnit.Size)))
		{
			_allUniforms[ui] = TextureUnit(tu);
			_textureIndices[parameter.name] = ui;
		}
		_textures.length = _textureIndices.length;

		auto userUniforms	= indexedUniforms.filter!(a => a[0].isUser)		.map!(a => tuple(a[0].name, a[1])).assocArray;
		_userUniforms		= userUniforms.assumeUnique;
	}

	this(this)
	{
		_allUniforms	= _allUniforms.dup;
		_textures		= _textures.dup;
	}

	private Uniform[] _allUniforms;
	private Texture[] _textures;
	private immutable uint[] _builtinUniforms;
	private immutable uint[string] _userUniforms;
	private immutable uint[string] _textureIndices;


}


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

package alias UniformSetter = void function(GLint location, ref const Uniform uniform);
package immutable UniformSetter[GLenum] uniformSetter;
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