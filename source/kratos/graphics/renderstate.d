module kratos.graphics.renderstate;

//import std.experimental.logger;
import kratos.graphics.gl;
import kgl3n.vector;
import kratos.resource.resource : ResourceIdentifier;

import kvibe.data.serialization;

struct RenderState
{
	enum Queue
	{
		Opaque,
		Transparent,
		UI
	}

	ResourceIdentifier id;
	Queue queue = Queue.Opaque;
	RenderStateCollection states;
	alias states this;
}

auto defaultRenderState()
{
	import kratos.graphics.shader : errorProgram;
	RenderState renderState;
	renderState.shader = Shader(errorProgram);
	return renderState;
}

private struct RenderStateCollection
{
	Cull		cull;
	Blend		blend;
	DepthTest	depthTest;
	Stencil		stencil;
	Shader		shader; // Should be package(kratos)

	void apply()
	{
		foreach(ref state; this.tupleof)
		{
			if(state != typeof(state).current)
			{
				state.apply();
			}
		}
	}
}

enum DepthFunc : GLenum
{
	Never			= GL_NEVER,
	Less			= GL_LESS,
	Equal			= GL_EQUAL,
	LessOrEqual		= GL_LEQUAL,
	Greater			= GL_GREATER,
	NotEqual		= GL_NOTEQUAL,
	GreaterOrEqual	= GL_GEQUAL,
	Always			= GL_ALWAYS
}

struct DepthTest
{
	@optional @byName:
	DepthFunc	func	= DepthFunc.LessOrEqual;
	bool		read	= true;
	bool		write	= true;

	private static current = DepthTest(DepthFunc.Less, false, true);

	void apply() const
	{
		if(current.func != func)	gl.DepthFunc(func);
		if(current.read != read)	gl.setEnabled(GL_DEPTH_TEST, read);
		if(current.write != write)	gl.DepthMask(write);

		current = this;
	}
}


enum BlendEquation : GLenum
{
	Add					= GL_FUNC_ADD,
	Subtract			= GL_FUNC_SUBTRACT,
	ReverseSubtract		= GL_FUNC_REVERSE_SUBTRACT,
	Min					= GL_MIN,
	Max					= GL_MAX
}

enum BlendFunction : GLenum
{
	Zero					= GL_ZERO,
	One						= GL_ONE,
	SrcColor				= GL_SRC_COLOR,
	OneMinusSrcColor		= GL_ONE_MINUS_SRC_COLOR,
	DstColor				= GL_DST_COLOR,
	OneMinusDstColor		= GL_ONE_MINUS_DST_COLOR,
	SrcAlpha				= GL_SRC_ALPHA,
	OneMinusSrcAlpha		= GL_ONE_MINUS_SRC_ALPHA,
	DstAlpha				= GL_DST_ALPHA,
	OneMinusDstAlpha		= GL_ONE_MINUS_DST_ALPHA,
	ConstantColor			= GL_CONSTANT_COLOR,
	OneMinusConstantColor	= GL_ONE_MINUS_CONSTANT_COLOR,
	ConstantAlpha			= GL_CONSTANT_ALPHA,
	OneMinusConstantAlpha	= GL_ONE_MINUS_CONSTANT_ALPHA,
	SrcAlphaSaturate		= GL_SRC_ALPHA_SATURATE
}

struct Blend
{
	@optional @byName:
	BlendEquation	rgbEquation			= BlendEquation.Add;
	BlendEquation	alphaEquation		= BlendEquation.Add;

	BlendFunction	srcRgbFunction		= BlendFunction.SrcAlpha;
	BlendFunction	srcAlphaFunction	= BlendFunction.SrcAlpha;
	BlendFunction	dstRgbFunction		= BlendFunction.OneMinusSrcAlpha;
	BlendFunction	dstAlphaFunction	= BlendFunction.OneMinusSrcAlpha;

	vec4			color				= vec4(0);
	bool			enabled				= false;

	@property
	{
		void equation(BlendEquation eq)
		{
			rgbEquation = eq;
			alphaEquation = eq;
		}

		void srcFunction(BlendFunction func)
		{
			srcRgbFunction = func;
			srcAlphaFunction = func;
		}

		void dstFunction(BlendFunction func)
		{
			dstRgbFunction = func;
			dstAlphaFunction = func;
		}
	}

	private static current = Blend(
		BlendEquation.Add, BlendEquation.Add,
		BlendFunction.One, BlendFunction.One,
		BlendFunction.Zero, BlendFunction.Zero,
		vec4(0), false);

	void apply() const
	{
		if(enabled)
		{
			if(current.rgbEquation != rgbEquation || 
			   current.alphaEquation != alphaEquation
			)
			{
				gl.BlendEquationSeparate(rgbEquation, alphaEquation);
			}

			if(current.srcRgbFunction != srcRgbFunction ||
			   current.srcAlphaFunction != srcAlphaFunction ||
			   current.dstRgbFunction != dstRgbFunction ||
			   current.dstAlphaFunction != dstRgbFunction)
			{
				gl.BlendFuncSeparate(srcRgbFunction, dstRgbFunction, srcAlphaFunction, dstAlphaFunction);
			}

			if(current.color != color) gl.BlendColor(color.r, color.g, color.b, color.a);
			if(current.enabled != enabled) gl.setEnabled(GL_BLEND, enabled);

			current = this;
		}
		else
		{
			if(current.enabled != enabled)
			{
				gl.setEnabled(GL_BLEND, enabled);
				current.enabled = enabled;
			}
		}
	}
}


enum FrontFace : GLenum
{
	Clockwise			= GL_CW,
	CounterClockwise	= GL_CCW
}

enum CullFace : GLenum
{
	Front			= GL_FRONT,
	Back			= GL_BACK,
	FrontAndBack	= GL_FRONT_AND_BACK
}

struct Cull
{
	@optional @byName:
	FrontFace	frontFace	= FrontFace.CounterClockwise;
	CullFace	cullFace	= CullFace.Back;
	bool		enabled		= true;

	private static current = Cull(FrontFace.CounterClockwise, CullFace.Back, false);

	void apply() const
	{
		if(current.frontFace != frontFace)	gl.FrontFace(frontFace);
		if(current.cullFace != cullFace)	gl.CullFace(cullFace);
		if(current.enabled != enabled)		gl.setEnabled(GL_CULL_FACE, enabled);

		current = this;
	}
}


enum StencilFunction : GLuint
{
	Never			= GL_NEVER,
	Less			= GL_LESS,
	LessOrEqual		= GL_LEQUAL,
	Greater			= GL_GREATER,
	GreaterOrEqual	= GL_GEQUAL,
	Equal			= GL_EQUAL,
	NotEqual		= GL_NOTEQUAL,
	Always			= GL_ALWAYS
}

enum StencilOp : GLuint
{
	Keep			= GL_KEEP,
	Zero			= GL_ZERO,
	Replace			= GL_REPLACE,
	Increment		= GL_INCR,
	IncrementWrap	= GL_INCR_WRAP,
	Decrement		= GL_DECR,
	DecrementWrap	= GL_DECR_WRAP,
	Invert			= GL_INVERT
}

struct Stencil
{
	@optional @byName:
	StencilFunction	stencilFunction		= StencilFunction.Always;
	StencilOp		stencilFail			= StencilOp.Keep;
	StencilOp		depthFail			= StencilOp.Keep;
	StencilOp		pass				= StencilOp.Keep;
	GLint			reference			= 0;
	GLuint			mask				= ~0;
	bool			enabled				= false;

	private static current = Stencil(
		StencilFunction.Always,
		StencilOp.Keep, StencilOp.Keep, StencilOp.Keep,
		0, ~0, false
	);

	void apply() const
	{
		if(enabled)
		{
			if(
				current.stencilFunction	!= stencilFunction	||
				current.reference		!= reference		||
				current.mask			!= mask
			) gl.StencilFunc(stencilFunction, reference, mask);

			if(
				current.stencilFail	!= stencilFail	||
				current.depthFail	!= depthFail	||
				current.pass		!= pass
			) gl.StencilOp(stencilFail, depthFail, pass);
			
			if(current.enabled != enabled)
				gl.setEnabled(GL_STENCIL_TEST, enabled);

			current = this;
		}
		else
		{
			if(current.enabled != enabled)
			{
				gl.setEnabled(GL_STENCIL_TEST, enabled);
				current.enabled = enabled;
			}
		}
	}
}

struct Shader
{
	import kratos.graphics.shader;
	import kratos.graphics.shadervariable;
	import std.typecons;

	private	Program		_program;
	private Uniforms	_uniforms;

	alias uniforms this;
	
	this(Program program)
	{
		//info("Creating Shader from Program ", program.name);
		_program = program;
		_uniforms = program.createUniforms();
	}

	void apply()
	{
		_program.use();
		_program.updateUniformValues(_uniforms);
	}
	
	@property const auto program()
	{
		return _program;
	}

	@property ref Uniforms uniforms()
	{
		return _uniforms;
	}
	
	@property string name() const
	{
		return _program.name;
	}

	private static struct Current { }
	private static Current current;

	bool opEquals(Current current)
	{
		//TODO: Test if initial equality test is faster. Probably not, at least one uniform differs in the general case.
		return false;
	}

	bool opEquals(ref const Shader shader)
	{
		foreach(i, ref field; this.tupleof)
		{
			if(shader.tupleof[i] != field) return false;
		}

		return true;
	}
}