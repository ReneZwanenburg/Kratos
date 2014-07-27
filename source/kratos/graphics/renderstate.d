﻿module kratos.graphics.renderstate;

import kratos.graphics.gl;
import gl3n.linalg;

struct RenderState
{
	Cull		cull;
	Blend		blend;
	DepthTest	depthTest;

	void apply()
	{
		foreach(state; this.tupleof)
		{
			if(state !is typeof(state).current)
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
	DepthFunc	func	= DepthFunc.LessOrEqual;
	bool		read	= true;
	bool		write	= true;

	private static current = DepthTest(DepthFunc.Less, false, true);

	void apply()
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

	void apply()
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
				gl.BlendFuncSeparate(srcRgbFunction, srcAlphaFunction, dstRgbFunction, dstAlphaFunction);
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
	FrontFace	frontFace	= FrontFace.CounterClockwise;
	CullFace	cullFace	= CullFace.Back;
	bool		enabled		= true;

	private static current = Cull(FrontFace.CounterClockwise, CullFace.Back, false);

	void apply()
	{
		if(current.frontFace != frontFace) gl.FrontFace(frontFace);
		if(current.cullFace != cullFace) gl.CullFace(cullFace);
		if(current.enabled != enabled) gl.setEnabled(GL_CULL_FACE, enabled);

		current = this;
	}
}