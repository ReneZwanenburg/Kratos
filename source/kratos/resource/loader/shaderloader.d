module kratos.resource.loader.shaderloader;

import kratos.resource.manager;
import kratos.resource.loader.internal;
import kratos.graphics.shader;
import kratos.graphics.texture : SamplerLoader, SamplerSettings;

alias ProgramLoader = Loader!(Program_Impl, loadProgram, true);
alias ShaderModuleLoader = Loader!(ShaderModule_Impl, loadShaderModule, true);

ShaderModule_Impl loadShaderModule(string name)
{
	auto buffer = activeFileSystem.get!char(name);
	return new ShaderModule_Impl(shaderExtensionType[name.lowerCaseExtension], buffer, name);
}

Program_Impl loadProgram(string name)
{
	auto json = loadJson(name);
	auto modulesJson = json["modules"].get!(Json[]);

	import std.algorithm : map;
	auto program = new Program_Impl(modulesJson.map!(a => ShaderModuleLoader.get(a.get!string)), name);

	auto samplersJson = json["samplers"];
	if(samplersJson.type != Json.Type.undefined)
	{
		foreach(string textureName, samplerJson; samplersJson)
		{
			import vibe.data.json : deserializeJson;
			program.setSampler(textureName, SamplerLoader.get(samplerJson.deserializeJson!SamplerSettings));
		}
	}
	
	return program;
}

private immutable ShaderStage[string] shaderExtensionType;

shared static this()
{
	shaderExtensionType = [
		".vert": ShaderStage.Vertex,
		".geom": ShaderStage.Geometry,
		".frag": ShaderStage.Fragment
	];
}