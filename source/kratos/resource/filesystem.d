module kratos.resource.filesystem;

private FileSystem _activeFileSystem;

@property FileSystem activeFileSystem()
{
	if(_activeFileSystem is null)
	{
		_activeFileSystem = new NormalFileSystem("assets/");
	}

	return _activeFileSystem;
}

@property void activeFileSystem(FileSystem fileSystem)
{
	_activeFileSystem = fileSystem;
}


interface FileSystem
{
	bool	has(string name);
	void[]	get(string name);
}

class MultiFileSystem : FileSystem
{
	private FileSystem[] _fileSystems;

	override bool	has(string name)
	{
		import std.algorithm : any;
		return _fileSystems.any!(a => a.has(name));
	}

	override void[]	get(string name)
	{
		assert(has(name));

		import std.algorithm : find;
		import std.array : front;
		return _fileSystems.find!(a => a.has(name)).front.get(name);
	}

	void push(FileSystem system)
	{
		_fileSystems ~= system;
	}
}

class NormalFileSystem : FileSystem
{
	import std.file;
	import std.array;

	private string _basePath;
	private Appender!(char[]) _pathBuilder;

	this(string basePath)
	{
		this._basePath = basePath;
	}

	override bool has(string name)
	{
		return buildPath(name).isFile();
	}

	override void[] get(string name)
	{
		return buildPath(name).read();
	}

	private const(char[]) buildPath(string name)
	{
		_pathBuilder.clear();
		_pathBuilder ~= _basePath;
		_pathBuilder ~= name;
		return _pathBuilder.data;
	}
}