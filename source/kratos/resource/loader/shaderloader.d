module kratos.resource.loader.shaderloader;

import kratos.resource.loader.internal;
import kratos.resource.cache;
import kratos.resource.resource;
import kratos.graphics.shader;

alias ShaderModuleCache = Cache!(ShaderModule, ResourceIdentifier, id => loadShaderModule(id));

private ShaderModule loadShaderModule(ResourceIdentifier name)
{
	auto buffer = activeFileSystem.get!char(name);
	return shaderModule(shaderExtensionType[name.lowerCaseExtension], buffer, name);
}


alias ProgramCache = Cache!(Program, ResourceIdentifier[], id => loadProgram(id));

private Program loadProgram(ResourceIdentifier[] modules)
{
	import std.algorithm : map;
	import std.conv : text;
	return program(modules.map!(a => ShaderModuleCache.get(a)), modules.text);
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