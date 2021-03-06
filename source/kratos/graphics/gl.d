﻿module kratos.graphics.gl;

public
{
	import derelict.opengl3.constants;
	import derelict.opengl3.types;
	import derelict.opengl3.ext : GL_TEXTURE_MAX_ANISOTROPY_EXT;
	import derelict.opengl3.ext : GL_COMPRESSED_RGB_S3TC_DXT1_EXT, GL_COMPRESSED_RGBA_S3TC_DXT3_EXT, GL_COMPRESSED_RGBA_S3TC_DXT5_EXT;
	import derelict.opengl3.arb;
	
	enum : uint
	{
		GL_COMPRESSED_SRGB_S3TC_DXT1_EXT		= 0x8C4C,
		GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT	= 0x8C4D,
		GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT	= 0x8C4E,
		GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT	= 0x8C4F
	}
}

import derelict.opengl3.gl3;
import kgl3n.vector;
import kgl3n.matrix;

import std.algorithm : joiner;
import std.conv : text;
//import std.experimental.logger;

/// Thin OpenGL wrapper. Performs glGetError() error checking in debug mode.
final abstract class gl
{
	static auto opDispatch(string functionName, Args...)(Args args) nothrow
	{
		//alias func = mixin("gl"~functionName); // Doesn't work, probably DMD bug
		mixin("alias func = gl" ~ functionName ~ ";");

		debug scope(success)
		{
			import std.exception : assumeWontThrow;
			assumeWontThrow(checkGLError!func(args));
		}

		return func(args);
	}

	static void setEnabled(GLenum target, bool enabled)
	{
		if(enabled)
		{
			gl.Enable(target);
		}
		else
		{
			gl.Disable(target);
		}
	}

	static GLuint genTexture()
	{
		GLuint handle;
		gl.GenTextures(1, &handle);
		return handle;
	}

	static GLuint genSampler()
	{
		GLuint handle;
		gl.GenSamplers(1, &handle);
		return handle;
	}
}

private void checkGLError(alias func, Args...)(Args args)
{
	if(auto errorCode = glGetError())
	{
		import std.traits : ParameterTypeTuple;
		import std.stdio : stderr;
		
		//errorf
		stderr.writefln("GL Error %s (%s)", errorCode, glEnumString.get(errorCode, "Unknown error code"));
		
		string[] stringifiedArgs;
		foreach(i, T; ParameterTypeTuple!func)
		{
			stringifiedArgs ~= args[i].text;
			
			static if(is(T == GLenum))
			{
				if(auto enumNames = args[i] in glEnumString)
				{
					stringifiedArgs[$-1] ~= "<" ~ glEnumString[args[i]] ~ ">";
				}
			}
		}
		//criticalf
		stderr.writefln("While calling %s(%s);", func.stringof, stringifiedArgs.joiner(", "));
		assert(false);
	}
}

template GLTypeBinding(GLenum _glType, T)
{
	enum glType = _glType;
	alias nativeType = T;
}

import std.typetuple;
import kratos.graphics.textureunit;
alias GLTypes = TypeTuple!(
	GLTypeBinding!(GL_FLOAT, float),
	GLTypeBinding!(GL_FLOAT_VEC2, vec2),
	GLTypeBinding!(GL_FLOAT_VEC3, vec3),
	GLTypeBinding!(GL_FLOAT_VEC4, vec4),

	GLTypeBinding!(GL_INT, int),
	GLTypeBinding!(GL_INT_VEC2, vec2i),
	GLTypeBinding!(GL_INT_VEC3, vec3i),
	GLTypeBinding!(GL_INT_VEC4, vec4i),

	GLTypeBinding!(GL_BOOL, bool),

	GLTypeBinding!(GL_FLOAT_MAT2, mat2),
	GLTypeBinding!(GL_FLOAT_MAT3, mat3),
	GLTypeBinding!(GL_FLOAT_MAT4, mat4),

	GLTypeBinding!(GL_SAMPLER_2D, TextureUnit)
);

template GLType(T)
{
	enum GLType = {
		foreach(B; GLTypes)
		{
			import std.traits : Unqual;
			static if(is(B.nativeType == Unqual!T)) return B.glType;
		}
		assert(false, "Not a valid OpenGL Type or Type not implemented");
	}();
}

immutable GLsizei[GLenum] GLTypeSize;
shared static this()
{
	foreach(B; GLTypes)
	{
		import std.algorithm : max;
		import std.conv : to;
		auto size = max(B.nativeType.sizeof, 4).to!GLenum;
		assert(size % 4 == 0, "GL Types should have four byte alignment");
		GLTypeSize[B.glType] = size;
	}
}

debug
{
	private immutable string[GLenum] glEnumString;
	static this()
	{
		string[][GLenum] tmp;
		foreach(member; __traits(allMembers, derelict.opengl3.constants))
		{
			static if(is(typeof(__traits(getMember, derelict.opengl3.constants, member)) == GLenum))
			{
				auto enumVal = __traits(getMember, derelict.opengl3.constants, member);
				tmp[enumVal] ~= member;
			}
		}
		
		foreach(key; tmp.byKey)
		{
			glEnumString[key] = tmp[key].joiner(" || ").text;
		}
	}
}


shared static this()
{
	DerelictGL3.load();
}

shared static ~this()
{
	DerelictGL3.unload();
}