module kratos.graphics.shader;

import kratos.resource.resource;
import kratos.graphics.gl;
import kratos.graphics.shadervariable;

import std.algorithm : copy, find;
import std.container : Array;
import std.conv : to;
import std.stdio : writeln; // TODO replace writeln with proper logging. Waiting for std.log
import std.range : isInputRange, take;


alias Program = Handle!Program_Impl;

Program program(Range)(Range shaders)
	//if(isInputRange!Range && is(ElementType!Range == ShaderModule)) // TODO re-enable contraint. DMD bug, fixed in 2.066
{
	auto program = initialized!Program;
	program.handle = gl.CreateProgram();
	debug writeln("Created Shader Program ", program.handle);
	shaders.copy(program.shaders.backInserter);

	foreach(shader; shaders)
	{
		gl.AttachShader(program.handle, shader.handle);
		shader.compileCallbacks.insertBack(&program.invalidate);
	}
	
	program.link();
	
	return program;
}

private struct Program_Impl
{
	private GLuint				handle;
	private Array!ShaderModule	shaders;
	ShaderParameter[]			attributes;
	ShaderParameter[]			uniforms;
	UniformSetter[]				uniformSetters;
	Uniform[]					uniformValues;
	bool						linked;
	
	@disable this(this);
	
	~this()
	{
		foreach(shader; shaders)
		{
			shader.compileCallbacks.linearRemove(shader.compileCallbacks[].find(&invalidate).take(1));
		}

		gl.DeleteProgram(handle);
		debug writeln("Deleted Shader Program ", handle);
	}

	/// Create an array of Uniforms for use with this Program
	Uniform[] createUniforms()
	{
		import std.algorithm : map;
		import std.array : array;
		return uniforms.map!Uniform.array;
	}

	void link()
	{
		if(linked) return;

		gl.LinkProgram(handle);
		GLint linkResult;
		gl.GetProgramiv(handle, GL_LINK_STATUS, &linkResult);
		
		if(!linkResult)
		{
			GLint logLength;
			gl.GetProgramiv(handle, GL_INFO_LOG_LENGTH, &logLength);
			assert(logLength > 0);
			
			auto log = new GLchar[](logLength);
			gl.GetProgramInfoLog(handle, log.length, null, log.ptr);
			writeln(log);
			
			assert(false);
		}
		else
		{
			linked = true;
		}


		// Workaround for forward reference error
		static void GetActiveAttrib_Impl(T...)(T args) { gl.GetActiveAttrib(args); }
		static void GetActiveUniform_Impl(T...)(T args) { gl.GetActiveUniform(args); }

		attributes		= getShaderParameters!(GL_ACTIVE_ATTRIBUTES, GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, GetActiveAttrib_Impl)();
		uniforms		= getShaderParameters!(GL_ACTIVE_UNIFORMS, GL_ACTIVE_UNIFORM_MAX_LENGTH, GetActiveUniform_Impl)();
		uniformSetters	= new UniformSetter[]	(uniforms.length);
		uniformValues	= createUniforms();
		
		import std.range : zip;
		foreach(const parameter, ref setter, ref value;
		        zip(uniforms, uniformSetters, uniformValues))
		{
			setter = uniformSetter[parameter.type];
			value.value = defaultUniformValue[parameter.type];
		}
	}

	private void invalidate()
	{
		linked = false;
	}

	private ShaderParameter[] getShaderParameters
		(
			GLenum ParameterCountGetter, 
			GLenum ParameterNameLengthGetter,
			alias ParameterGetter
		)()
	{
		GLint numParameters;
		gl.GetProgramiv(handle, ParameterCountGetter, &numParameters);
		
		if(numParameters > 0)
		{
			GLint maxNameLength;
			gl.GetProgramiv(handle, ParameterNameLengthGetter, &maxNameLength);
			assert(maxNameLength > 0, "Shader Parameter declared without name. Please verify the universe is in a consistent state.");
			
			auto parameters = new ShaderParameter[](numParameters);
			auto parameterName = new GLchar[](maxNameLength);
			
			foreach(parameterIndex; 0..numParameters)
			{
				GLsizei nameLength;
				ParameterGetter(
					handle,
					parameterIndex,
					parameterName.length,
					&nameLength,
					&parameters[parameterIndex].size,
					&parameters[parameterIndex].type,
					parameterName.ptr
				);
				
				parameters[parameterIndex].name = parameterName[0..nameLength].idup;
			}
			
			return parameters;
		}
		else
		{
			return null;
		}
	}
}


alias ShaderModule = Handle!ShaderModule_Impl;

ShaderModule shaderModule(ShaderModule.Type type, const(GLchar)[] shaderSource)
{
	auto shader = initialized!ShaderModule;
	shader.type = type;
	shader.handle = gl.CreateShader(type);
	
	debug writeln("Created ", type, " Shader ", shader.handle);

	shader.source = shaderSource;
	shader.compile();
	
	return shader;
}

private struct ShaderModule_Impl
{
	enum Type : GLenum
	{
		Vertex		= GL_VERTEX_SHADER,
		Geometry	= GL_GEOMETRY_SHADER,
		Fragment	= GL_FRAGMENT_SHADER
	}
	
	private GLuint			handle;
	private Type			type;
	// Used to mark programs as dirty. Use delegates because of lack of weak references to RefCounted
	Array!(void delegate())	compileCallbacks;
	private bool			compiled;
	
	@disable this(this);
	
	~this()
	{
		gl.DeleteShader(handle);
		debug writeln("Deleted ", type, " Shader ", handle);
	}

	@property void source(const(GLchar)[] source)
	{
		const srcPtr = source.ptr;
		const srcLength = source.length.to!GLint;
		gl.ShaderSource(handle, 1, &srcPtr, &srcLength);
		compiled = false;
	}

	void compile()
	{
		if(compiled) return;

		gl.CompileShader(handle);

		GLint compileStatus;
		gl.GetShaderiv(handle, GL_COMPILE_STATUS, &compileStatus);

		if(!compileStatus)
		{
			GLint logLength;
			gl.GetShaderiv(handle, GL_INFO_LOG_LENGTH, &logLength);
			assert(logLength > 0);
			
			auto log = new GLchar[](logLength);
			gl.GetShaderInfoLog(handle, log.length, null, log.ptr);
			
			writeln("Error compiling ", type, " Shader ", handle, ":");
			writeln(log);
			
			assert(false);
		}
		else
		{
			compiled = true;
			foreach(callback; compileCallbacks) callback();
		}
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