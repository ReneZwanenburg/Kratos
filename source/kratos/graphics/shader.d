module kratos.graphics.shader;

import kratos.graphics.gl;
import kratos.graphics.shadervariable;
import kratos.graphics.texture;
import kratos.util : backInserter, StaticString, linearRemove;
import kratos.resource.manager;

import std.algorithm : copy, find, map;
import std.array : array;
import std.container : Array;
import std.conv : to;
import std.exception : assumeUnique;
import std.range : isInputRange, take, repeat;
import std.experimental.logger;


alias ProgramManager = Manager!Program_Impl;
alias Program = ProgramManager.Handle;

alias ShaderModuleManager = Manager!ShaderModule_Impl;
alias ShaderModule = ShaderModuleManager.Handle;

Program errorProgram()
{
	static Program errorProgram;
	
	if(!errorProgram.refCountedStore.isInitialized)
	{
		auto vertexSource = "#version 330\n mat4 mvp; in vec3 position; void main() {gl_Position = mvp * vec4(position, 1); }";
		auto fragmentSource = "#version 330\n void main() { gl_FragData[0] = vec4(1, 0, 1, 1); }";

		errorProgram = ProgramManager.create(
			[
				ShaderModuleManager.create(ShaderStage.Vertex, vertexSource, "Error Vertex Shader"),
				ShaderModuleManager.create(ShaderStage.Fragment, fragmentSource, "Error Fragment Shader")
			]
			, "Error Program");
	}
	return errorProgram;
}

class Program_Impl
{
	private	string				_name;
	private GLuint				handle;
	private Array!ShaderModule	shaders;
	private	VertexAttributes	_attributes;
	private Uniforms			_uniforms;
	private Array!Sampler		_samplers;
	
	this(Range)(Range modules, string name = null)
	{
		import std.conv : text;

		handle	= gl.CreateProgram();
		_name	= name ? name : handle.text;
		info("Created Shader Program ", this.name);
		modules.copy(this.shaders.backInserter);

		foreach(shader; modules)
		{
			auto shaderImpl = ShaderModuleManager.getConcreteResource(shader);
			gl.AttachShader(handle, shaderImpl.handle);
		}

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
			gl.GetProgramInfoLog(handle, cast(GLsizei)log.length, null, log.ptr);
			
			throw new Exception(log.assumeUnique);
		}

		info("Linking Program ", name, " successful");
		

		gl.GetProgramiv(handle, GL_ACTIVE_ATTRIBUTES, &_attributes.count);

		foreach(i; 0 .. _attributes.count)
		{
			VertexAttribute attribute;

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

			auto location = gl.GetAttribLocation(
				handle,
				attribute.name.data.ptr
			);

			assert(0 <= location && location < _attributes.count);
			_attributes[location] = attribute;
		}
		
		
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
			nameBuffer.length = maxNameLength;
		}

		ptrdiff_t offset = 0;
		foreach(GLuint i, ref uniform; allUniforms)
		{
			GLsizei nameLength;
			
			gl.GetActiveUniform(
				handle,
				i,
				cast(GLsizei)nameBuffer.length,
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

		this._uniforms = Uniforms(allUniforms);
		
		_samplers = typeof(_samplers)(defaultSampler.repeat(_uniforms.textureCount));

		use();
		_uniforms.initializeSamplerIndices();

		//TODO: Update Shaders using this Program
	}
	
	~this()
	{
		gl.DeleteProgram(handle);
		info("Deleted Shader Program ", name);
	}

	/// Create an array of Uniforms for use with this Program
	Uniforms createUniforms()
	{
		return _uniforms;
	}

	void setSampler(string name, Sampler sampler)
	{
		if(auto indexPtr = _uniforms.getSamplerIndex(name))
		{
			_samplers[*indexPtr] = sampler;
		}
	}

	void use() const
	{
		static GLuint current = 0;

		if(current != handle)
		{
			//trace("Binding Program ", name);
			gl.UseProgram(handle);
			current = handle;
		}
	}

	package void updateUniformValues(ref Uniforms uniforms)
	{
		_uniforms.apply(uniforms, _samplers);
	}

	@property const
	{
		auto attributes()	{ return _attributes;	}
		string name() 		{ return _name;			}
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


enum ShaderStage : GLenum
{
	Vertex		= GL_VERTEX_SHADER,
	Geometry	= GL_GEOMETRY_SHADER,
	Fragment	= GL_FRAGMENT_SHADER
}

class ShaderModule_Impl
{
	private string			_name;
	private GLuint			handle;
	private ShaderStage		type;
	
	this(ShaderStage type, const(GLchar)[] shaderSource, string name = null)
	{
		import std.conv : text;

		this.type = type;
		handle = gl.CreateShader(type);
		_name = name ? name : handle.text;

		info("Created ", type, " Shader ", this.name);

		const srcPtr = shaderSource.ptr;
		const srcLength = shaderSource.length.to!GLint;
		gl.ShaderSource(handle, 1, &srcPtr, &srcLength);
		
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
			gl.GetShaderInfoLog(handle, cast(GLsizei)log.length, null, log.ptr);
			
			throw new Exception(log.assumeUnique);
		}
		else
		{
			info("Compiling Shader ", name, " successful");
		}
	}
	
	~this()
	{
		gl.DeleteShader(handle);
		info("Deleted ", type, " Shader ", name);
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
