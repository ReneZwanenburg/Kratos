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
	bool			has(string name);
	const(void[])	get(string name);
}

class MultiFileSystem : FileSystem
{
	private FileSystem[] _fileSystems;

	override bool has(string name)
	{
		import std.algorithm : any;
		return _fileSystems.any!(a => a.has(name));
	}

	override const(void[]) get(string name)
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

	override const(void[]) get(string name)
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

class PackFileSystem : FileSystem
{
	import std.mmfile;
	import std.digest.md;

	alias FileHash = ubyte[digestLength!MD5];

	static struct FileOffset
	{
		ulong startOffset;
		ulong endOffset;
	}

	static struct FileInfo
	{
		FileHash	hash;
		FileOffset	offset;
	}

	private MmFile					_pack;
	private FileOffset[FileHash]	_fileMap;

	this(string packFile)
	{
		_pack = new MmFile(packFile);

		import std.bitmanip;
		uint numFiles = (cast(uint[])_pack[0..uint.sizeof])[0];

		foreach(file; cast(FileInfo[])_pack[uint.sizeof .. uint.sizeof + numFiles * FileInfo.sizeof])
		{
			_fileMap[file.hash] = file.offset;
		}
	}

	override bool has(string name)
	{
		return !!(md5Of(name) in _fileMap);
	}
	
	override const(void[]) get(string name)
	{
		auto offset = _fileMap[md5Of(name)];
		return _pack[offset.startOffset .. offset.endOffset];
	}
}