module kratos.graphics.shader;

import kratos.resource.resource;
import kratos.graphics.gl;
import kratos.graphics.shadervariable;

import std.algorithm : copy, find, map;
import std.array : array;
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
	const(GLchar)[]				errorLog;
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

			this.errorLog = log;
		}
		else
		{
			this.errorLog = null;
			linked = true;
		}


		// Workaround for forward reference error
		static void GetActiveAttrib_Impl(T...)(T args) { gl.GetActiveAttrib(args); }
		static void GetActiveUniform_Impl(T...)(T args) { gl.GetActiveUniform(args); }

		attributes		= getShaderParameters!(GL_ACTIVE_ATTRIBUTES, GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, GetActiveAttrib_Impl)();
		uniforms		= getShaderParameters!(GL_ACTIVE_UNIFORMS, GL_ACTIVE_UNIFORM_MAX_LENGTH, GetActiveUniform_Impl)();
		uniformSetters	= uniforms.map!(a => uniformSetter[a.type]).array;
		uniformValues	= createUniforms();
	}

	@property bool hasErrors() const
	{
		return !!errorLog.length;
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

unittest
{
	import kratos.window;
	auto window = Window(unittestWindowProperties);

	auto vertexShader = shaderModule(
		ShaderModule.Type.Vertex,
		"in vec3 position; in float w; uniform vec3 offset; void main(){gl_Position = vec4(position + offset, w);}"
	);
	auto fragmentShader = shaderModule(
		ShaderModule.Type.Fragment,
		"uniform vec4 color; void main(){gl_FragData[0] = color;}"
	);

	import std.range;
	import std.algorithm;
	auto prog = program(only(vertexShader, fragmentShader));

	auto expectedAttributes = only(ShaderParameter(1, GL_FLOAT_VEC3, "position"), ShaderParameter(1, GL_FLOAT, "w"));
	auto expectedUniforms = [ShaderParameter(1, GL_FLOAT_VEC3, "offset"), ShaderParameter(1, GL_FLOAT_VEC4, "color")].sort!((a, b) => cmp(a.name, b.name)>0);

	assert(!prog.hasErrors);
	assert(prog.linked);
	assert(prog.shaders[].equal(only(vertexShader, fragmentShader)));
	assert(prog.attributes.equal(expectedAttributes));
	assert(prog.uniforms.dup.sort!((a, b) => cmp(a.name, b.name)>0).equal(expectedUniforms));


	vertexShader.source = "in vec3 position; void main(){gl_Position = vec4(position, 1);}";
	vertexShader.compile();
	assert(!prog.linked);
	prog.link();
	assert(prog.linked);
	assert(prog.attributes.equal(only(ShaderParameter(1, GL_FLOAT_VEC3, "position"))));
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
	private const(GLchar)[]	errorLog;
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

	@property bool hasErrors() const
	{
		return !!errorLog.length;
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

			this.errorLog = log;
		}
		else
		{
			compiled = true;
			errorLog = null;
			foreach(callback; compileCallbacks) callback();
		}
	}
}

unittest
{
	import kratos.window;
	auto window = Window(unittestWindowProperties);

	auto shader = shaderModule(ShaderModule.Type.Vertex, "void main(){}");
	assert(shader.compiled);
	shader.source = "void main";
	assert(!shader.compiled);
	shader.compile();
	assert(!shader.compiled);
	assert(shader.hasErrors);
	assert(shader.errorLog.length);

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