module kratos.resource.loader.shaderloader;

import kratos.resource.loader.internal;
import kratos.resource.cache;
import kratos.resource.resource;
import kratos.graphics.shader;

import kratos.graphics.texture : sampler, SamplerSettings;

alias ShaderModuleCache = Cache!(ShaderModule, ResourceIdentifier, id => loadShaderModule(id));

private ShaderModule loadShaderModule(ResourceIdentifier name)
{
	auto buffer = activeFileSystem.get!char(name);
	return shaderModule(shaderExtensionType[name.lowerCaseExtension], buffer, name);
}


alias ProgramCache = Cache!(Program, ResourceIdentifier, id => loadProgram(id));

private Program loadProgram(ResourceIdentifier name)
{
	auto json = loadJson(name);
	auto modulesJson = json["modules"].get!(Json[]);

	import std.algorithm : map;
	auto program = program(modulesJson.map!(a => ShaderModuleCache.get(a.get!string)), name);

	auto samplersJson = json["samplers"];
	if(samplersJson.type != Json.Type.undefined)
	{
		foreach(string textureName, samplerJson; samplersJson)
		{
			import kvibe.data.json : deserializeJson;
			program.setSampler(textureName, sampler(samplerJson.deserializeJson!SamplerSettings));
		}
	}


	return program;
}

private immutable ShaderModule.Type[string] shaderExtensionType;

shared static this()
{
	shaderExtensionType = [
		".vert": ShaderModule.Type.Vertex,
		".geom": ShaderModule.Type.Geometry,
		".frag": ShaderModule.Type.Fragment
	];
}