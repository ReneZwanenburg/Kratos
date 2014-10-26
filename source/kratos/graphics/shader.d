module kratos.graphics.shader;

import kratos.resource.resource;
import kratos.graphics.gl;
import kratos.graphics.shadervariable;
import kratos.graphics.texture;
import kratos.util : backInserter, StaticString;

import std.algorithm : copy, find, map;
import std.array : array;
import std.container : Array;
import std.conv : to;
import std.range : isInputRange, take, repeat;
import std.experimental.logger;


alias Program = Handle!Program_Impl;

Program program(Range)(Range shaders, string name = null)
	//if(isInputRange!Range && is(ElementType!Range == ShaderModule)) // TODO re-enable contraint. DMD bug, fixed in 2.066
{
	import std.conv : text;

	auto program	= initialized!Program;
	program.handle	= gl.CreateProgram();
	program._name	= name ? name : program.handle.text;
	info("Created Shader Program ", program.name);
	shaders.copy(program.shaders.backInserter);

	foreach(shader; shaders)
	{
		gl.AttachShader(program.handle, shader.handle);
		shader.compileCallbacks.insertBack(&program.invalidate);
	}
	
	program.link();
	
	return program;
}

Program errorProgram()
{
	import std.range : only;
	static Program errorProgram;
	static bool initialized = false;
	if(!initialized)
	{
		auto vertexSource = "mat4 mvp; in vec3 position; void main() {gl_Position = mvp * vec4(position, 1); }";
		auto fragmentSource = "void main() { gl_FragData[0] = vec4(1, 0, 1, 1); }";

		errorProgram = program(
			only(
				shaderModule(ShaderModule.Type.Vertex, vertexSource, "Error Vertex Shader"),
				shaderModule(ShaderModule.Type.Fragment, fragmentSource, "Error Fragment Shader")
			), "Error Program");
	}
	return errorProgram;
}

private struct Program_Impl
{
	private	string				_name;
	private GLuint				handle;
	private Array!ShaderModule	shaders;
	//TODO Use fixed size array to store attributes.
	private	VertexAttributes	_attributes;
	private Uniforms			_uniforms;
	private Array!Sampler		_samplers;
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
		info("Deleted Shader Program ", name);
	}

	/// Create an array of Uniforms for use with this Program
	Uniforms createUniforms()
	{
		return _uniforms;
	}

	void link()
	{
		if(_linked) return;

		info("Linking Program ", name);

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

			warningf("Linking Program %s failed:\n%s", name, log);

			return;
		}

		info("Linking Program ", name, " successful");
		this._errorLog = null;
		_linked = true;

		updateAttributes();
		updateUniforms();
		_samplers = typeof(_samplers)(defaultSampler.repeat(_uniforms.textureCount));

		//TODO: Update Shaders using this Program
	}

	void use() const
	{
		static GLuint current = 0;

		if(current != handle)
		{
			trace("Binding Program ", name);
			gl.UseProgram(handle);
			current = handle;
		}
	}

	@property bool hasErrors() const
	{
		return !!_errorLog.length;
	}

	private void invalidate()
	{
		info("Invalidating Program ", name);
		_linked = false;
	}

	package void updateUniformValues(ref Uniforms uniforms)
	{
		_uniforms.apply(uniforms, _samplers);
	}

	@property const
	{
		auto attributes()	{ return _attributes; }
		auto errorLog()		{ return _errorLog; }
	}

	private void updateAttributes()
	{
		VertexAttributes attributes;

		gl.GetProgramiv(handle, GL_ACTIVE_ATTRIBUTES, &attributes.count);

		foreach(i, ref attribute; attributes[])
		{
			GLsizei nameLength;
			GLsizei size;

			gl.GetActiveAttrib(
				handle,
				i,
				StaticString.MaxLength,
				&nameLength,
				&size,
				&attribute.aggregateType,
				attribute.name.data.ptr
			);

			assert(size == 1, "Attribute arrays not supported yet");
			attribute.name.length = cast(typeof(attribute.name.length))nameLength;
		}

		this._attributes = attributes;
	}

	private void updateUniforms()
	{
		Uniform[] allUniforms;

		{
			GLsizei numUniforms;
			gl.GetProgramiv(handle, GL_ACTIVE_UNIFORMS, &numUniforms);
			allUniforms = new Uniform[numUniforms];
		}
		
		static GLchar[] nameBuffer;
		{
			GLint maxNameLength;
			gl.GetProgramiv(handle, GL_ACTIVE_UNIFORM_MAX_LENGTH, &maxNameLength);
			nameBuffer.assumeSafeAppend;
			nameBuffer.length = maxNameLength;
		}

		ptrdiff_t offset = 0;
		foreach(i, ref uniform; allUniforms)
		{
			GLsizei nameLength;
			
			gl.GetActiveUniform(
				handle,
				i,
				nameBuffer.length,
				&nameLength,
				&uniform.size,
				&uniform.type,
				nameBuffer.ptr
			);

			uniform.name = nameBuffer[0..nameLength].idup;
			uniform.offset = offset;
			uniform.byteSize = GLTypeSize[uniform.type] * uniform.size;

			offset += uniform.byteSize;
		}

		import std.exception : assumeUnique;
		this._uniforms = Uniforms(allUniforms.assumeUnique);
	}

	@property string name() const
	{
		return _name;
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
	auto expectedUniforms = 
		[ShaderParameter(1, GL_FLOAT_VEC3, "offset"), ShaderParameter(1, GL_FLOAT_VEC4, "color")]
		.sort!((a, b) => cmp(a.name, b.name)>0);

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

ShaderModule shaderModule(ShaderModule.Type type, const(GLchar)[] shaderSource, string name = null)
{
	import std.conv : text;

	auto shader = initialized!ShaderModule;
	shader.type = type;
	shader.handle = gl.CreateShader(type);
	shader._name = name ? name : shader.handle.text;

	info("Created ", type, " Shader ", shader.name);

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

	private string			_name;
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
		info("Deleted ", type, " Shader ", name);
	}

	@property void source(const(GLchar)[] source)
	{
		info("Updating Shader ", name, " source");
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

		info("Compiling Shader ", name);
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

			warningf("Compiling Shader %s failed:\n%s", name, log);
		}
		else
		{
			info("Compiling Shader ", name, " successful");
			compiled = true;
			errorLog = null;
			foreach(callback; compileCallbacks) callback();
		}
	}

	@property string name() const
	{
		return _name;
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
