module kratos.graphics.gl.gl;

public
{
	import derelict.opengl3.constants;
	import derelict.opengl3.types;
}

import derelict.opengl3.gl3;
import gl3n.linalg;

import std.algorithm : joiner;
import std.conv : text;

/// Thin OpenGL wrapper. Performs glGetError() error checking in debug mode.
final abstract class gl
{
	static auto opDispatch(string functionName, Args...)(Args args)
	{
		enum fullFunctionName = "gl"~functionName;
		mixin("alias func = " ~ fullFunctionName ~ ";");

		import std.traits : ReturnType;
		static if(!is(ReturnType!func == void))
		{
			auto retVal = func(args);
		}
		else
		{
			func(args);
		}

		debug
		{
			if(auto errorCode = glGetError())
			{
				import std.stdio : writefln;
				import std.traits : ParameterTypeTuple;

				writefln("GL Error %s (%s)", errorCode, glEnumString.get(errorCode, "Unknown error code"));

				string[] stringifiedArgs;
				foreach(i, T; ParameterTypeTuple!func)
				{
					stringifiedArgs ~= args[i].text;

					static if(is(T == GLenum))
					{
						if(auto enumNames = args[i] in glEnumString)
						{
							stringifiedArgs ~= "(" ~ glEnumString[args[i]] ~ ")";
						}
					}
				}
				writefln("While calling %s(%s);", fullFunctionName, stringifiedArgs.joiner(", "));

				assert(false);
			}
		}

		static if(!is(ReturnType!func == void))
		{
			return retVal;
		}
	}
}

template GLType(T)
{
	static if(is(T == float))
	{
		enum GLType = GL_FLOAT;
	}
	else static if(is(T == vec2))
	{
		enum GLType = GL_FLOAT_VEC2;
	}
	else static if(is(T == vec3))
	{
		enum GLType = GL_FLOAT_VEC3;
	}
	else static if(is(T == vec4))
	{
		enum GLType = GL_FLOAT_VEC4;
	}
	else static if(is(T == int))
	{
		enum GLType = GL_INT;
	}
	else static if(is(T == vec2i))
	{
		enum GLType = GL_INT_VEC2;
	}
	else static if(is(T == vec3i))
	{
		enum GLType = GL_INT_VEC3;
	}
	else static if(is(T == vec4i))
	{
		enum GLType = GL_INT_VEC4;
	}
	else static if(is(T == bool))
	{
		enum GLType = GL_BOOL;
	}
	else static if(is(T == mat2))
	{
		enum GLType = GL_FLOAT_MAT2;
	}
	else static if(is(T == mat3))
	{
		enum GLType = GL_FLOAT_MAT3;
	}
	else static if(is(T == mat4))
	{
		enum GLType = GL_FLOAT_MAT4;
	}
	
	else static assert(false, "Not a valid OpenGL Type or Type not implemented");
}

immutable GLsizei[GLenum] GLTypeSize;
shared static this()
{
	GLTypeSize = [
		GL_FLOAT		: float.sizeof,
		GL_FLOAT_VEC2	: vec2.sizeof,
		GL_FLOAT_VEC3	: vec3.sizeof,
		GL_FLOAT_VEC4	: vec4.sizeof,
		
		GL_INT			: int.sizeof,
		GL_INT_VEC2		: vec2i.sizeof,
		GL_INT_VEC3		: vec3i.sizeof,
		GL_INT_VEC4		: vec4i.sizeof,
		
		GL_BOOL			: bool.sizeof,
		
		GL_FLOAT_MAT2	: mat2.sizeof,
		GL_FLOAT_MAT3	: mat3.sizeof,
		GL_FLOAT_MAT4	: mat4.sizeof
	];
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