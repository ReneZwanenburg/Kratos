module kratos.graphics.gl.gl;

public
{
	import derelict.opengl3.constants;
	import derelict.opengl3.types;
}

import derelict.opengl3.gl3;

import std.algorithm : joiner;
import std.conv : text;

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