module kratos.resource.loader.renderstateloader;

import kratos.resource.manager;
import kratos.resource.loader.internal;
import kratos.graphics.renderstate;
import vibe.data.json;
import kratos.resource.loader.shaderloader;
import kratos.resource.loader.textureloader;
import kratos.graphics.texture;

alias RenderStateLoader = Loader!(RenderState, loadRenderState, false);

RenderState loadRenderState(string name)
{
	auto json = loadJson(name);

	if(json["parent"].type == Json.Type.undefined)
	{
		auto renderState = RenderState(name);
		
		auto queue = json["queue"];
		if(queue.type != Json.Type.undefined)
		{
			import std.conv : to;
			renderState.queue = queue.get!string.to!(RenderState.Queue);
		}

		foreach(ref field; renderState.states.tupleof)
		{
			alias T = typeof(field);
			auto stateJson = json[T.stringof];
			if(stateJson.type == Json.Type.Undefined) continue;
			
			static if(is(T == Shader))
			{
				field = Shader(ProgramLoader.get(stateJson["program"].get!string));
				loadUniforms(renderState, stateJson["uniforms"]);
			}
			else
			{
				field = deserializeJson!T(stateJson);
			}
		}

		return renderState;
	}
	else
	{
		auto renderState = RenderStateLoader.get(json["parent"].get!string);
		loadUniforms(renderState, json["uniforms"]);
		return renderState;
	}
}

private void loadUniforms(ref RenderState renderState, Json uniforms)
{
	if(uniforms.type != Json.Type.Undefined)
	{
		foreach(string name, value; uniforms)
		{
			if(value.type == Json.Type.String)
			{
				renderState.shader[name] = TextureLoader.get(value.get!string);
			}
			else
			{
				auto uniformType = renderState.shader.getGlType(name);
				
				import kratos.graphics.gl;
				foreach(TypeBinding; GLTypes)
				{
					alias UT = TypeBinding.nativeType;
					if(TypeBinding.glType == uniformType)
					{
						//TODO: Add support for uniform arrays and matrices
						static if(!is(UT == TextureUnit))
						{
							renderState.shader.uniforms[name] = deserializeJson!(UT)(value);
						}
					}
				}
			}
		}
	}
}