module kratos.graphics.shadervariable;

import kratos.graphics.gl;

import std.variant;
import gl3n.linalg;

import std.conv : text;
import std.typetuple : TypeTuple, staticIndexOf;


struct ShaderParameter
{
	GLint	size; // Size in 'type' units, not byte size
	GLenum	type;
	string	name;
	
	@property GLsizei byteSize() const pure nothrow
	{
		return size * GLTypeSize[type];
	}

	@property GLenum backingType() const pure nothrow
	{
		return .backingType[type];
	}

	@property GLint backingTypeSize() const pure nothrow
	{
		return .backingTypeSize[type];
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

	package @property ref const(UniformValue) valueStore() const
	{
		return value;
	}

	package @property void valueStore(ref const UniformValue value)
	{
		this.value = value;
	}
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
	mat4
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