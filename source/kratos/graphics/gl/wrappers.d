module kratos.graphics.gl.wrappers;

import kratos.resource.resource : Handle;
import kratos.graphics.gl.gl;

import std.conv : to;
import std.stdio : writeln; // TODO replace writeln with proper logging. Waiting for std.log
import std.typecons : RefCounted, RefCountedAutoInitialize;
import std.range : isInputRange, ElementType;
import std.container : Array;
import std.algorithm : copy;


alias VAO = Handle!VAO_Impl;

VAO vao()
{
	auto vao = initialized!VAO;
	gl.GenVertexArrays(1, &vao.handle);
	debug writeln("Created Vertex Array Object ", vao.handle);
	return vao;
}

private struct VAO_Impl
{
	private GLuint handle;

	@disable this(this);

	~this()
	{
		gl.DeleteVertexArrays(1, &handle);
		debug writeln("Deleted Vertex Array Object ", handle);
	}

	void bind()
	{
		gl.BindVertexArray(handle);
	}
}

alias VBO = BO!GL_ARRAY_BUFFER;
alias vbo = bo!GL_ARRAY_BUFFER;

alias IBO = BO!GL_ELEMENT_ARRAY_BUFFER;
alias ibo = bo!GL_ELEMENT_ARRAY_BUFFER;

private alias BO(GLenum Target) = Handle!(BO_Impl!Target);

private BO!Target bo(GLenum Target)()
{
	auto bo = initialized!(BO!Target);
	gl.GenBuffers(1, &bo.handle);
	debug writeln("Created Buffer Object ", bo.handle);
	return bo;
}

private struct BO_Impl(GLenum Target)
{
	private GLuint handle;

	@disable this(this);

	~this()
	{
		gl.DeleteBuffers(1, &handle);
		debug writeln("Deleted Buffer Object ", handle);
	}
}

void bind(GLenum Target)(BO!Target bo)
{
	gl.BindBuffer(Target, bo.handle);
}


struct ShaderVariable
{
	GLint				size;
	GLenum				type;
	immutable(GLchar)[]	name; // D-like string. No null terminator.
}


alias Program = Handle!Program_Impl;

Program program(Range)(Range shaders)
if(isInputRange!Range && is(ElementType!Range == Shader))
{
	auto program = initialized!Program;
	program.handle = gl.CreateProgram();
	debug writeln("Created Shader Program ", program.handle);
	shaders.copy(program.shaders.backInserter);
	
	foreach(shader; shaders)
	{
		gl.AttachShader(program.handle, shader.handle);
	}
	
	gl.LinkProgram(program.handle);
	GLint linkResult;
	gl.GetProgramiv(program.handle, GL_LINK_STATUS, &linkResult);
	
	if(!linkResult)
	{
		GLint logLength;
		gl.GetProgramiv(program.handle, GL_INFO_LOG_LENGTH, &logLength);
		assert(logLength > 0);
		
		auto log = new GLchar[](logLength);
		gl.GetProgramInfoLog(program.handle, log.length, null, log.ptr);
		writeln(log);
		
		assert(false);
	}

	static ShaderVariable[] getShaderVariables
		(
			GLenum VariableCountGetter, 
			GLenum VariableNameLengthGetter,
			alias VariableGetter
		)
		(
			ref Program program
		)
	{
		GLint numVariables;
		gl.GetProgramiv(program.handle, VariableCountGetter, &numVariables);
		
		if(numVariables > 0)
		{
			GLint maxNameLength;
			gl.GetProgramiv(program.handle, VariableNameLengthGetter, &maxNameLength);
			assert(maxNameLength > 0, "Shader Variable declared without name. Please verify the universe is in a consistent state.");
			
			auto variables = new ShaderVariable[](numVariables);
			auto variableName = new GLchar[](maxNameLength);

			foreach(variableIndex; 0..numVariables)
			{
				GLsizei nameLength;
				VariableGetter(
					program.handle,
					variableIndex,
					variableName.length,
					&nameLength,
					&variables[variableIndex].size,
					&variables[variableIndex].type,
					variableName.ptr
				);
				
				variables[variableIndex].name = variableName[0..nameLength].idup;
			}

			return variables;
		}
		else
		{
			return null;
		}
	}

	// Workaround for forward reference error
	static void GetActiveAttrib_Impl(T...)(T args) { gl.GetActiveAttrib(args); }
	static void GetActiveUniform_Impl(T...)(T args) { gl.GetActiveUniform(args); }

	program.attributes = getShaderVariables!(GL_ACTIVE_ATTRIBUTES, GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, GetActiveAttrib_Impl)(program);
	program.uniforms = getShaderVariables!(GL_ACTIVE_UNIFORMS, GL_ACTIVE_UNIFORM_MAX_LENGTH, GetActiveUniform_Impl)(program);
	
	return program;
}

private struct Program_Impl
{
	private GLuint handle;
	private Array!Shader shaders;
	ShaderVariable[] attributes;
	ShaderVariable[] uniforms;

	@disable this(this);

	~this()
	{
		gl.DeleteProgram(handle);
		debug writeln("Deleted Shader Program ", handle);
	}
}


alias Shader = Handle!Shader_Impl;

Shader shader(Shader.Type type, const(GLchar)[] shaderSource)
{
	auto shader = initialized!Shader;
	shader.type = type;
	shader.handle = gl.CreateShader(type);
	
	debug writeln("Created ", type, " Shader ", shader.handle);
	
	const srcPtr = shaderSource.ptr;
	const srcLength = shaderSource.length.to!int;
	gl.ShaderSource(shader.handle, 1, &srcPtr, &srcLength);
	
	gl.CompileShader(shader.handle);
	
	GLint compileStatus;
	gl.GetShaderiv(shader.handle, GL_COMPILE_STATUS, &compileStatus);
	if(!compileStatus)
	{
		GLint logLength;
		gl.GetShaderiv(shader.handle, GL_INFO_LOG_LENGTH, &logLength);
		assert(logLength > 0);
		
		auto log = new GLchar[](logLength);
		gl.GetShaderInfoLog(shader.handle, log.length, null, log.ptr);

		writeln("Error compiling ", type, " Shader ", shader.handle, ":");
		writeln(log);
		
		assert(false);
	}
	
	return shader;
}

private struct Shader_Impl
{
	enum Type : GLenum
	{
		Vertex		= GL_VERTEX_SHADER,
		Geometry	= GL_GEOMETRY_SHADER,
		Fragment	= GL_FRAGMENT_SHADER
	}

	private GLuint	handle;
	private Type	type;

	@disable this(this);

	~this()
	{
		gl.DeleteShader(handle);
		debug writeln("Deleted ", type, " Shader ", handle);
	}
}

//TODO move everything below to a more appropriate place
import gl3n.linalg;

template GLType(T)
{
	static if(is(T == float))
	{
		enum GLType = GL_FLOAT;
	}
	else static if(is(T == vec2))
	{
		enum GLType = GL_FLOAT_VEC2;
	}
	else static if(is(T == vec3))
	{
		enum GLType = GL_FLOAT_VEC3;
	}
	else static if(is(T == vec4))
	{
		enum GLType = GL_FLOAT_VEC4;
	}
	else static if(is(T == int))
	{
		enum GLType = GL_INT;
	}
	else static if(is(T == vec2i))
	{
		enum GLType = GL_INT_VEC2;
	}
	else static if(is(T == vec3i))
	{
		enum GLType = GL_INT_VEC3;
	}
	else static if(is(T == vec4i))
	{
		enum GLType = GL_INT_VEC4;
	}
	else static if(is(T == bool))
	{
		enum GLType = GL_BOOL;
	}
	else static if(is(T == mat2))
	{
		enum GLType = GL_FLOAT_MAT2;
	}
	else static if(is(T == mat3))
	{
		enum GLType = GL_FLOAT_MAT3;
	}
	else static if(is(T == mat4))
	{
		enum GLType = GL_FLOAT_MAT4;
	}

	else static assert(false, "Not a valid OpenGL Type or Type not implemented");
}

immutable int[GLenum] GLTypeSize;
shared static this()
{
	GLTypeSize = [
		GL_FLOAT		: float.sizeof,
		GL_FLOAT_VEC2	: vec2.sizeof,
		GL_FLOAT_VEC3	: vec3.sizeof,
		GL_FLOAT_VEC4	: vec4.sizeof,

		GL_INT			: int.sizeof,
		GL_INT_VEC2		: vec2i.sizeof,
		GL_INT_VEC3		: vec3i.sizeof,
		GL_INT_VEC4		: vec4i.sizeof,

		GL_BOOL			: bool.sizeof,

		GL_FLOAT_MAT2	: mat2.sizeof,
		GL_FLOAT_MAT3	: mat3.sizeof,
		GL_FLOAT_MAT4	: mat4.sizeof
	];
}

private auto initialized(T)() if(is(T == RefCounted!S, S...))
{
	T refCounted;
	refCounted.refCountedStore.ensureInitialized();
	return refCounted;
}

private auto backInserter(T)(ref Array!T array)
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