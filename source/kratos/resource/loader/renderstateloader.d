module kratos.resource.loader.renderstateloader;

import kratos.resource.loader.internal;
import kratos.resource.cache;
import kratos.resource.resource;
import kratos.graphics.renderstate;
import vibe.data.json;
import kratos.resource.loader.shaderloader;
import kratos.resource.loader.textureloader;
import kratos.graphics.textureunit;

alias RenderStateCache = Cache!(RenderState, ResourceIdentifier, id => loadRenderState(id));

private RenderState loadRenderState(ResourceIdentifier name)
{
	RenderState renderState;
	auto json = parseJsonString(activeFileSystem.get!char(name));
	
	foreach(ref field; renderState.tupleof)
	{
		alias T = typeof(field);
		auto stateJson = json[T.stringof];
		if(stateJson.type == Json.Type.Undefined) continue;
		
		static if(is(T == Shader))
		{
			auto modules = deserializeJson!(string[])(stateJson["modules"]);
			import std.algorithm : sort;
			modules.sort();
			
			renderState.shader = Shader(ProgramCache.get(modules));
			
			auto uniforms = stateJson["uniforms"];
			if(uniforms.type != Json.Type.Undefined)
			{
				foreach(string name, value; uniforms)
				{
					if(value.type == Json.Type.String)
					{
						renderState.shader[name] = TextureCache.get(value.get!string);
					}
					else
					{
						auto uniform = renderState.shader[name];
						
						import kratos.graphics.gl;
						foreach(TypeBinding; GLTypes)
						{
							alias UT = TypeBinding.nativeType;
							if(TypeBinding.glType == uniform.type)
							{
								//TODO: Add support for uniform arrays and matrices
								static if(!is(UT == TextureUnit))
								{
									uniform = deserializeJson!(UT)(value);
								}
							}
						}
					}
				}
			}
		}
		else
		{
			field = deserializeJson!T(stateJson);
		}
	}
	
	return renderState;
}