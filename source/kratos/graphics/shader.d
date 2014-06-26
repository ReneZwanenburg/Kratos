module kratos.graphics.shader;

import kratos.resource.resource;
import kratos.graphics.gl;
import kratos.graphics.shadervariable;

import std.container : Array;
import std.conv : to;
import std.stdio : writeln; // TODO replace writeln with proper logging. Waiting for std.log


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


//TODO move to a more appropriate place
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