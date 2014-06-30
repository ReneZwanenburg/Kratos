module kratos.graphics.shadervariable;

import kratos.graphics.gl;

import std.variant;
import gl3n.linalg;


struct GLVariable
{
	GLint				size; // Size in 'type' units, not byte size
	GLenum				type;
	immutable(GLchar)[]	name; // D-like string. No null terminator.
	
	@property GLsizei byteSize() const pure nothrow
	{
		return size * GLTypeSize[type];
	}
}

GLsizei totalByteSize(const GLVariable[] variables)
{
	import std.algorithm : reduce;
	return reduce!q{a + b.byteSize}(0, variables);
}


struct Uniform
{
	GLVariable type;
	Algebraic!GLTypes value;
	UniformSetter setter;

	@disable this();

	this(GLVariable type)
	{
		this.type = type;
		setter = uniformSetters[type.type];
	}

	ref auto opAssign(T)(auto ref T value)
	{
		assert(GLType!T == type.type, "Uniform type mismatch: " ~ T.stringof);
		this.value = value;
	}
}

alias UniformSetter = void function(GLint location, ref Uniform uniform);
private immutable UniformSetter[GLenum] uniformSetters;
static this()
{
	foreach(T; GLTypes)
	{
		enum type = GLType!T;

		static if(is(T == float))
			uniformSetters[type] = (location, ref uniform) => gl.Uniform1fv(location, uniform.type.size, uniform.value.peek!float);
		else static if(is(T == vec2))
			uniformSetters[type] = (location, ref uniform) => gl.Uniform2fv(location, uniform.type.size, uniform.value.peek!float);
		else static if(is(T == vec3))
			uniformSetters[type] = (location, ref uniform) => gl.Uniform3fv(location, uniform.type.size, uniform.value.peek!float);
		else static if(is(T == vec4))
			uniformSetters[type] = (location, ref uniform) => gl.Uniform4fv(location, uniform.type.size, uniform.value.peek!float);

		else static if(is(T == int))
			uniformSetters[type] = (location, ref uniform) => gl.Uniform1iv(location, uniform.type.size, uniform.value.peek!int);
		else static if(is(T == vec2i))
			uniformSetters[type] = (location, ref uniform) => gl.Uniform2iv(location, uniform.type.size, uniform.value.peek!int);
		else static if(is(T == vec3i))
			uniformSetters[type] = (location, ref uniform) => gl.Uniform3iv(location, uniform.type.size, uniform.value.peek!int);
		else static if(is(T == vec4i))
			uniformSetters[type] = (location, ref uniform) => gl.Uniform4iv(location, uniform.type.size, uniform.value.peek!int);

		else static if(is(T == bool))
			uniformSetters[type] = (location, ref uniform) => gl.Uniform1iv(location, uniform.type.size, uniform.value.peek!int);

		else static if(is(T == mat2))
			uniformSetters[type] = (location, ref uniform) => gl.UniformMatrix2fv(location, uniform.type.size, false, uniform.value.peek!float);
		else static if(is(T == mat3))
			uniformSetters[type] = (location, ref uniform) => gl.UniformMatrix3fv(location, uniform.type.size, false, uniform.value.peek!float);
		else static if(is(T == mat4))
			uniformSetters[type] = (location, ref uniform) => gl.UniformMatrix4fv(location, uniform.type.size, false, uniform.value.peek!float);

		else static assert(false, "No uniform setter implemented for " ~ T.stringof);
	}
}