module kratos.resource.loader.internal;

public import kratos.resource.loader.jsonloader;
public import kratos.resource.filesystem;

package @property auto lowerCaseExtension(string path)
{
	import std.path : extension;
	import std.string : toLower;
	return path.extension.toLower();
}