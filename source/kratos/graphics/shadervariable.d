module kratos.graphics.shadervariable;

import kratos.graphics.gl;

import std.variant;
import gl3n.linalg;

import std.conv : text;
import std.typetuple : TypeTuple;


struct ShaderParameter
{
	GLint	size; // Size in 'type' units, not byte size
	GLenum	type;
	string	name;
	
	@property GLsizei byteSize() const pure nothrow
	{
		return size * GLTypeSize[type];
	}
}

GLsizei totalByteSize(const ShaderParameter[] parameters)
{
	import std.algorithm : reduce;
	return reduce!q{a + b.byteSize}(0, parameters);
}

package alias UniformValue = Algebraic!ShaderParameterTypes;

struct Uniform
{
	const	ShaderParameter	parameter;
	private	UniformValue	value;

	@disable this();

	this(ShaderParameter parameter)
	{
		this.parameter = parameter;
		this.value = defaultUniformValue[parameter.type];
	}

	ref auto opAssign(T)(auto ref T value)
	{
		assert(GLType!T == parameter.type, "Uniform type mismatch: " ~ T.stringof);
		this.value = value;
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

package alias UniformSetter = void function(GLint location, ref Uniform uniform);
package immutable UniformSetter[GLenum] uniformSetter;
static this()
{
	foreach(T; ShaderParameterTypes)
	{
		enum type = GLType!T;

		static if(is(T == float))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform1fv(location, uniform.parameter.size, uniform.value.peek!float);
		else static if(is(T == vec2))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform2fv(location, uniform.parameter.size, uniform.value.peek!float);
		else static if(is(T == vec3))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform3fv(location, uniform.parameter.size, uniform.value.peek!float);
		else static if(is(T == vec4))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform4fv(location, uniform.parameter.size, uniform.value.peek!float);

		else static if(is(T == int))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform1iv(location, uniform.parameter.size, uniform.value.peek!int);
		else static if(is(T == vec2i))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform2iv(location, uniform.parameter.size, uniform.value.peek!int);
		else static if(is(T == vec3i))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform3iv(location, uniform.parameter.size, uniform.value.peek!int);
		else static if(is(T == vec4i))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform4iv(location, uniform.parameter.size, uniform.value.peek!int);

		else static if(is(T == bool))
			uniformSetter[type] = (location, ref uniform) => gl.Uniform1iv(location, uniform.parameter.size, uniform.value.peek!int);

		else static if(is(T == mat2))
			uniformSetter[type] = (location, ref uniform) => gl.UniformMatrix2fv(location, uniform.parameter.size, false, uniform.value.peek!float);
		else static if(is(T == mat3))
			uniformSetter[type] = (location, ref uniform) => gl.UniformMatrix3fv(location, uniform.parameter.size, false, uniform.value.peek!float);
		else static if(is(T == mat4))
			uniformSetter[type] = (location, ref uniform) => gl.UniformMatrix4fv(location, uniform.parameter.size, false, uniform.value.peek!float);

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
			defaultUniformValue[type] = T.identity;
		}
		else
		{
			defaultUniformValue[type] = UniformValue(T.init);
		}
	}
}