module kratos.graphics.shader;

import kratos.resource.resource;
import kratos.graphics.gl;
import kratos.graphics.shadervariable;

import std.algorithm : copy, find, map;
import std.array : array;
import std.container : Array;
import std.conv : to;
import std.range : isInputRange, take;
import std.logger;


struct Shader
{
	private	Program		_program;
	private Uniform[]	_uniforms;

	@disable this();

	this(this)
	{
		_uniforms = _uniforms.dup;
	}

	this(Program program)
	{
		info("Creating Shader from Program ", program.handle); //TODO: Print Program name instead
		_program = program;
		_uniforms = program.createUniforms();
	}

	//TODO: Testing code. Remove
	void prepare()
	{
		_program.use();
		_program.setUniforms(_uniforms);
	}

	@property const auto program()
	{
		return _program;
	}

	ref Uniform opIndex(string name)
	{
		import std.algorithm : find;
		import std.array : front;
		return _uniforms.find!q{a.parameter.name == b}(name).front;
	}
}

alias Program = Handle!Program_Impl;

Program program(Range)(Range shaders)
	//if(isInputRange!Range && is(ElementType!Range == ShaderModule)) // TODO re-enable contraint. DMD bug, fixed in 2.066
{
	auto program = initialized!Program;
	program.handle = gl.CreateProgram();
	info("Created Shader Program ", program.handle);
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
	//TODO Use fixed size array to store attributes.
	private	ShaderParameter[]	_attributes;
	private	ShaderParameter[]	_uniforms;
	private	UniformSetter[]		_uniformSetters;
	private	Uniform[]			_uniformValues;
	private	const(GLchar)[]		_errorLog;
	private	bool				_linked;
	
	@disable this(this);
	
	~this()
	{
		foreach(shader; shaders)
		{
			shader.compileCallbacks.linearRemove(shader.compileCallbacks[].find(&invalidate).take(1));
		}

		gl.DeleteProgram(handle);
		info("Deleted Shader Program ", handle);
	}

	/// Create an array of Uniforms for use with this Program
	Uniform[] createUniforms()
	{
		import std.algorithm : map;
		import std.array : array;
		return _uniforms.map!Uniform.array;
	}

	void link()
	{
		if(_linked) return;

		info("Linking Program ", handle);

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
			this._errorLog = log;

			warningf("Linking Program %s failed:\n%s", handle, log);

			return;
		}

		info("Linking Program ", handle, " successful");
		this._errorLog = null;
		_linked = true;

		// Workaround for forward reference error
		static void GetActiveAttrib_Impl(T...)(T args) { gl.GetActiveAttrib(args); }
		static void GetActiveUniform_Impl(T...)(T args) { gl.GetActiveUniform(args); }

		_attributes		= getShaderParameters!(GL_ACTIVE_ATTRIBUTES, GL_ACTIVE_ATTRIBUTE_MAX_LENGTH, GetActiveAttrib_Impl)();
		_uniforms		= getShaderParameters!(GL_ACTIVE_UNIFORMS, GL_ACTIVE_UNIFORM_MAX_LENGTH, GetActiveUniform_Impl)();
		_uniformSetters	= _uniforms.map!(a => uniformSetter[a.type]).array;
		_uniformValues	= createUniforms();

		trace("Program ", handle, " vertex attributes:\n", _attributes);
		trace("Program ", handle, " uniforms:\n", _uniforms);

		//TODO: Update Shaders using this Program
	}

	void use()
	{
		trace("Binding Program ", handle);
		gl.UseProgram(handle);
	}

	@property bool hasErrors() const
	{
		return !!_errorLog.length;
	}

	private void invalidate()
	{
		trace("Invalidating Program ", handle);
		_linked = false;
	}

	private void setUniforms(const Uniform[] uniforms)
	{
		//TODO: Ensure this program is currently bound
		import std.range : zip, iota;

		foreach(i, ref currentVal, ref newVal; zip(_uniforms.length.iota, _uniformValues, uniforms))
		{
			if(currentVal !is newVal)
			{
				_uniformSetters[i](i, newVal);
				currentVal = newVal;
			}
		}
	}

	@property const
	{
		auto attributes()	{ return _attributes; }
		auto uniforms()		{ return _uniforms; }
		auto errorLog()		{ return _errorLog; }
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

	info("Created ", type, " Shader ", shader.handle);

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
		info("Deleted ", type, " Shader ", handle);
	}

	@property void source(const(GLchar)[] source)
	{
		info("Updating Shader ", handle, " source");
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

		info("Compiling Shader ", handle);
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
			this.errorLog = log;

			warningf("Compiling Shader %s failed:\n%s", handle, log);
		}
		else
		{
			info("Compiling Shader ", handle, " successful");
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