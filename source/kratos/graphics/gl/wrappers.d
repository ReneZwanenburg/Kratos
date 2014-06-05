module kratos.graphics.gl.wrappers;

import kratos.graphics.gl.gl;

import std.conv : to;
import std.stdio : writeln; // TODO replace writeln with proper logging. Waiting for std.log
import std.typecons : RefCounted, RefCountedAutoInitialize;
import std.range : isInputRange, ElementType;
import std.container : Array;


private alias Handle(T) = RefCounted!(T, RefCountedAutoInitialize.no);


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


struct VertexAttribute
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
	foreach(shader; shaders) program.shaders.insertBack(shader);
	
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
	
	GLint numVertexAttribs;
	gl.GetProgramiv(program.handle, GL_ACTIVE_ATTRIBUTES, &numVertexAttribs);

	if(numVertexAttribs > 0)
	{
		GLint maxAttribLength;
		gl.GetProgramiv(program.handle, GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, &maxAttribLength);
		assert(maxAttribLength > 0, "Vertex Attributes declared without name. Please verify the universe is in a consistent state.");

		program.attributes = new VertexAttribute[](numVertexAttribs);
		auto attribName = new GLchar[](maxAttribLength);
		
		foreach(attribIndex; 0..numVertexAttribs)
		{
			GLsizei nameLength;
			gl.GetActiveAttrib(
				program.handle,
				attribIndex,
				attribName.length,
				&nameLength,
				&program.attributes[attribIndex].size,
				&program.attributes[attribIndex].type,
				attribName.ptr
			);
			
			program.attributes[attribIndex].name = attribName[0..nameLength].idup;
		}
	}
	
	return program;
}

private struct Program_Impl
{
	private GLuint handle;
	private Array!Shader shaders;
	VertexAttribute[] attributes;

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

//TODO move to a more appropriate place
private auto initialized(T)() if(is(T == RefCounted!S, S...))
{
	T refCounted;
	refCounted.refCountedStore.ensureInitialized();
	return refCounted;
}