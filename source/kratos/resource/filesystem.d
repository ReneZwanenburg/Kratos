module kratos.resource.filesystem;

import std.exception : assumeUnique;
import std.experimental.logger;

private __gshared FileSystem _activeFileSystem;

@property FileSystem activeFileSystem()
{
	//TODO: Make thread-safe
	if(_activeFileSystem is null)
	{
		import std.file;
		if(exists("LoadOrder.json"))
		{
			import vibe.data.json;
			auto json = parseJsonString(readText("LoadOrder.json"));

			auto mfs = new MultiFileSystem();
			_activeFileSystem = mfs;

			foreach(element; json)
			{
				auto name = element.get!string;
				import std.path;
				if(name.extension == ".assetpack")
				{
					mfs.push(new PackFileSystem(name));
				}
				else
				{
					mfs.push(new NormalFileSystem(name));
				}
			}
		}
		else
		{
			_activeFileSystem = new NormalFileSystem("assets/");
		}
	}

	return _activeFileSystem;
}

@property void activeFileSystem(FileSystem fileSystem)
{
	_activeFileSystem = fileSystem;
}

struct RawFileData
{
	string name;
	string extension;
	immutable(void)[] data;
	
	@disable this();
	
	this(string name, string extension, immutable(void)[] data)
	{
		import std.uni : toLower;
		
		this.name = name;
		this.extension = (extension.length && extension[0] == '.' ? extension[1 .. $] : extension).toLower;
		this.data = data;
	}
	
	@property T[] as(T)()
	{
		return cast(T[]) data;
	}
	
	@property string asText()
	{
		return as!(immutable char);
	}
}

interface FileSystem
{
	bool has(string name);

	protected RawFileData	getImpl(string name);

	final RawFileData	get(string name)
	{
		assert(has(name), "File '" ~ name ~ "' does not exist");
		return getImpl(name);
	}

	void write(RawFileData data);

	@property bool writable() const;
}

class MultiFileSystem : FileSystem
{
	private FileSystem[] _fileSystems;
	private FileSystem _writableFileSystem;

	override bool has(string name)
	{
		import std.algorithm : any;
		return _fileSystems.any!(a => a.has(name));
	}

	override RawFileData getImpl(string name)
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

	override void write(RawFileData data)
	{
		assert(writable);
		_writableFileSystem.write(data);
	}
}

class NormalFileSystem : FileSystem
{
	import std.file;
	import std.array;
	import std.path;

	private string _basePath;
	private Appender!(char[]) _pathBuilder;

	//TODO: Protect against escapting the base path
	
	this(string basePath)
	{
		this._basePath = buildNormalizedPath(basePath);
	}

	override bool has(string name)
	{
		return !findByName(name).empty;
	}

	override RawFileData getImpl(string name)
	{
		auto path = findByName(name);
		info("Reading ", path);
		return RawFileData(name, path.extension, path.read.assumeUnique);
	}
	
	private string findByName(string name)
	{
		import std.algorithm.iteration : filter;
	
		auto pattern = buildNormalizedPath(_basePath, name);
		auto entries = 
			dirEntries(dirName(pattern), baseName(pattern) ~ ".*", SpanMode.shallow)
			.filter!(a => a.isFile)
			.filter!(a => a.baseName == name);
		
		if(entries.empty) return null;
		
		auto firstEntry = entries.front;
		entries.popFront;
		if(!entries.empty) warningf("%s: Multipe entries for %s", _basePath, name);
		return firstEntry;
	}

	/*
	private const(char[]) buildPath(string name)
	{
		_pathBuilder.clear();
		_pathBuilder ~= _basePath;
		_pathBuilder ~= name;
		return _pathBuilder.data;
	}
	*/

	@property override bool writable() const
	{
		return true;
	}

	override void write(RawFileData data) {
		auto path = buildNormalizedPath(_basePath, data.name ~ '.' ~ data.extension);
		mkdirRecurse(dirName(path));
		std.file.write(path, data.data);
	}

}

class PackFileSystem : FileSystem
{
	import std.mmfile;

	private MmFile					_pack;
	private RawFileData[string]		_fileMap;
	private string					_packName;

	this(string packFile)
	{
		_packName = packFile;
		_pack = new MmFile(packFile);

		import std.bitmanip;
		uint numFiles = (cast(uint[])_pack[0..uint.sizeof])[0];
	
		static struct FileOffset
		{
			ulong startOffset;
			ulong endOffset;
		}
		
		import std.algorithm.iteration : splitter;
		
		auto fileInfos = cast(FileOffset[])_pack[uint.sizeof .. uint.sizeof + numFiles * FileOffset.sizeof];
		auto fileNamesInfo = fileInfos[0];
		auto fileNames = (cast(string)_pack[fileNamesInfo.startOffset .. fileNamesInfo.endOffset]).splitter('\0');
		
		import std.range : zip;
	
		foreach(fileInfo, name; zip(fileInfos[1 .. $], fileNames))
		{
			import std.path : extension, stripExtension;
		
			auto data = RawFileData(name.stripExtension, name.extension, _pack[fileInfo.startOffset .. fileInfo.endOffset].assumeUnique);
			_fileMap[data.name] = data;
		}
	}

	override bool has(string name)
	{
		return !!(name in _fileMap);
	}
	
	override RawFileData getImpl(string name)
	{
		info("Reading ", _packName, " : ", name);
		return _fileMap[name];
	}

	@property override bool writable() const
	{
		return false;
	}

	override void write(RawFileData)
	{
		assert(false);
	}
}