module kratos.graphics.gl.wrappers;

import kratos.resource.resource : Handle, initialized;
import kratos.graphics.gl.gl;

import std.conv : to, text;
import std.stdio : writeln; // TODO replace writeln with proper logging. Waiting for std.log
import std.typecons : RefCounted, RefCountedAutoInitialize;
import std.range : isInputRange, ElementType;
import std.container : Array;
import std.algorithm : copy;


alias VAO = Handle!VAO_Impl;

// VBO should probably own it's variables. Then just pass IBO, VBO, Program.
VAO vao(IBO ibo, VBO vbo, ShaderVariable[] vboVariables, ShaderVariable[] programVariables)
{
	auto vao = initialized!VAO;
	gl.GenVertexArrays(1, &vao.handle);
	debug writeln("Created Vertex Array Object ", vao.handle);

	vao.bind();
	ibo.bind();
	vbo.bind();

	const stride = vboVariables.totalByteSize;

	foreach(programIndex, programVariable; programVariables)
	{
		import std.algorithm : countUntil;

		const vboIndex = vboVariables.countUntil!q{a.name == b.name}(programVariable);
		assert(vboIndex >= 0, "VBO does not contain variable '" ~ programVariable.name ~ "': " ~ vboVariables.text);
		const vboVariable = vboVariables[vboIndex];

		gl.EnableVertexAttribArray(programIndex);
		gl.VertexAttribPointer(
			programIndex,
			vboVariable.size,
			vboVariable.type,
			false,
			stride,
			cast(GLvoid*)vboVariables[0..vboIndex].totalByteSize
		);
	}

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

	void bind()
	{
		gl.BindBuffer(Target, handle);
	}
}


struct ShaderVariable
{
	GLint				size; // Size in 'type' units, not byte size
	GLenum				type;
	immutable(GLchar)[]	name; // D-like string. No null terminator.

	@property GLsizei byteSize() const pure nothrow
	{
		return size * GLTypeSize[type];
	}
}

private GLsizei totalByteSize(const ShaderVariable[] variables)
{
	import std.algorithm : reduce;
	return reduce!q{a + b.byteSize}(0, variables);
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