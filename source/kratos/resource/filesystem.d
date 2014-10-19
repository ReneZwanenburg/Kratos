module kratos.resource.filesystem;

import std.exception : assumeUnique;
import kratos.resource.resource : ResourceIdentifier;
import std.experimental.logger;

private __gshared FileSystem _activeFileSystem;

@property FileSystem activeFileSystem()
{
	//TODO: Make thread-safe
	if(_activeFileSystem is null)
	{
		auto mfs = new MultiFileSystem();
		_activeFileSystem = mfs;

		mfs.push(new NormalFileSystem("assets/"));

		import std.file;
		foreach(file; dirEntries("./", "*.assetpack", SpanMode.breadth))
		{
			mfs.push(new PackFileSystem(file.name));
		}
	}

	return _activeFileSystem;
}

@property void activeFileSystem(FileSystem fileSystem)
{
	_activeFileSystem = fileSystem;
}


interface FileSystem
{
	bool				has(ResourceIdentifier name);

	protected
	immutable(void)[]	getImpl(ResourceIdentifier name);

	final
	immutable(void)[]	get(ResourceIdentifier name)
	{
		assert(has(name), "File " ~ name ~ " does not exist");
		return getImpl(name);
	}

	immutable(T)[]		get(T)(ResourceIdentifier name)
	{
		return cast(immutable (T)[])get(name);
	}

	final
	auto				getText(ResourceIdentifier name)
	{
		return get!char(name);
	}

	void				write(ResourceIdentifier name, const void[] data);

	@property bool 		writable() const;
}

class MultiFileSystem : FileSystem
{
	private FileSystem[] _fileSystems;
	private FileSystem _writableFileSystem;

	override bool has(ResourceIdentifier name)
	{
		import std.algorithm : any;
		return _fileSystems.any!(a => a.has(name));
	}

	override immutable(void[]) getImpl(ResourceIdentifier name)
	{
		import std.algorithm : find;
		import std.array : front;
		return _fileSystems.find!(a => a.has(name)).front.get(name);
	}

	void push(FileSystem system)
	{
		_fileSystems ~= system;

		if(!writable && system.writable)
		{
			_writableFileSystem = system;
		}
	}

	@property override bool writable() const {
		return _writableFileSystem !is null;
	}

	override void write(ResourceIdentifier name, const void[] data)
	{
		assert(writable);
		_writableFileSystem.write(name, data);
	}
}

class NormalFileSystem : FileSystem
{
	import std.file;
	import std.array;
	import std.path : dirName;

	private string _basePath;
	private Appender!(char[]) _pathBuilder;

	this(string basePath)
	{
		this._basePath = basePath;
	}

	override bool has(ResourceIdentifier name)
	{
		auto path = buildPath(name);
		return path.exists && path.isFile;
	}

	override immutable(void)[] getImpl(ResourceIdentifier name)
	{
		auto path = buildPath(name);
		info("Reading ", path);
		return path.read().assumeUnique;
	}

	private const(char[]) buildPath(ResourceIdentifier name)
	{
		_pathBuilder.clear();
		_pathBuilder ~= _basePath;
		_pathBuilder ~= name;
		return _pathBuilder.data;
	}

	@property override bool writable() const
	{
		return true;
	}

	override void write(ResourceIdentifier name, const void[] data) {
		auto path = buildPath(name);
		mkdirRecurse(dirName(path));
		std.file.write(path, data);
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
	private string					_fileName;

	this(string packFile)
	{
		_fileName = packFile;
		_pack = new MmFile(packFile);

		import std.bitmanip;
		uint numFiles = (cast(uint[])_pack[0..uint.sizeof])[0];

		foreach(file; cast(FileInfo[])_pack[uint.sizeof .. uint.sizeof + numFiles * FileInfo.sizeof])
		{
			_fileMap[file.hash] = file.offset;
		}
	}

	override bool has(ResourceIdentifier name)
	{
		return !!(md5Of(name) in _fileMap);
	}
	
	override immutable(void)[] getImpl(ResourceIdentifier name)
	{
		info("Reading ", _fileName, " : ", name);
		auto offset = _fileMap[md5Of(name)];
		return _pack[offset.startOffset .. offset.endOffset].assumeUnique;
	}

	@property override bool writable() const
	{
		return false;
	}

	override void write(ResourceIdentifier name, const void[] data)
	{
		assert(false);
	}
}