module kratos.graphics.texture;

import kratos.graphics.gl;
import kgl3n.vector;
import kgl3n.math;
//import std.experimental.logger;
import kratos.resource.manager;

import vibe.data.serialization : optional, byName;

public import kratos.graphics.textureunit;


alias TextureManager = Manager!Texture_Impl;
alias Texture = TextureManager.Handle;

alias SamplerManager = Manager!Sampler_Impl;
alias SamplerLoader = Loader!(Sampler_Impl, (SamplerSettings a) => new Sampler_Impl(a), true);
alias Sampler = SamplerLoader.StoredResource;


enum SamplerMinFilter : GLenum
{
	Nearest		= GL_NEAREST,
	Bilinear	= GL_LINEAR,
	Trilinear	= GL_LINEAR_MIPMAP_LINEAR
}

enum SamplerMagFilter : GLenum
{
	Nearest		= GL_NEAREST,
	Bilinear	= GL_LINEAR
}

enum SamplerWrap : GLenum
{
	Repeat			= GL_REPEAT,
	MirroredRepeat	= GL_MIRRORED_REPEAT,
	Clamp			= GL_CLAMP_TO_EDGE
}

struct SamplerAnisotropy
{
	this(int level)
	{
		assert(level <= maxAnisotropy);
		this._level = level;
	}

	alias level this;
	@property int level() const nothrow
	{
		return _level;
	}

	int toRepresentation() const nothrow
	{
		return _level;
	}

	static SamplerAnisotropy fromRepresentation(int level)
	{
		return SamplerAnisotropy(level);
	}

	enum int maxAnisotropy = 16;
	private int _level = 1;
}

Sampler defaultSampler()
{
	return SamplerLoader.get(SamplerSettings.init);
}

private class Sampler_Impl
{
	private const GLuint		handle;
	const SamplerSettings		settings;

	this(SamplerSettings settings)
	{
		handle = gl.genSampler;
		this.settings = settings;
		
		gl.SamplerParameteri(handle, GL_TEXTURE_MIN_FILTER, settings.minFilter);
		gl.SamplerParameteri(handle, GL_TEXTURE_MAG_FILTER, settings.magFilter);
		gl.SamplerParameteri(handle, GL_TEXTURE_WRAP_S, settings.xWrap);
		gl.SamplerParameteri(handle, GL_TEXTURE_WRAP_T, settings.yWrap);
		gl.SamplerParameteri(handle, GL_TEXTURE_MAX_ANISOTROPY_EXT, settings.anisotropy);
	}
	
	~this()
	{
		gl.DeleteSamplers(1, &handle);
	}
}

struct SamplerSettings
{
	@optional @byName:
	SamplerMinFilter	minFilter	= SamplerMinFilter.Trilinear;
	SamplerMagFilter	magFilter	= SamplerMagFilter.Bilinear;
	SamplerWrap			xWrap		= SamplerWrap.Repeat;
	SamplerWrap			yWrap		= SamplerWrap.Repeat;
	SamplerAnisotropy	anisotropy	= 1;
}

struct TextureFormat
{
	GLenum	bufferFormat;
	GLenum	internalFormat;
	GLenum	type;
	uint	bitsPerPixel;
	
	@property
	{
		bool bufferFormatIsCompressed() const
		{
			return isCompressedFormat(bufferFormat);
		}
		
		bool internalFormatIsCompressed() const
		{
			return isCompressedFormat(internalFormat);
		}
	}
	
	public TextureFormat asCompressed() const
	{
		static GLenum[GLenum] internalFormatToCompressedMapping;
		if(internalFormatToCompressedMapping is null) internalFormatToCompressedMapping =
		[
			GL_RGB8:	GL_COMPRESSED_RGB_S3TC_DXT1_EXT,
			GL_RGBA8:	GL_COMPRESSED_RGBA_S3TC_DXT5_EXT
		];
	
		TextureFormat retVal = this;
		if(auto compressedFormatPtr = retVal.internalFormat in internalFormatToCompressedMapping)
		{
			retVal.internalFormat = *compressedFormatPtr;
		}
		return retVal;
	}
	
	public TextureFormat asDownloadFormat() const
	{
		TextureFormat retVal = this;
		
		if(internalFormatIsCompressed)
		{
			retVal.bufferFormat = internalFormat;
			
			if(internalFormat == GL_COMPRESSED_RGB_S3TC_DXT1_EXT)
			{
				retVal.bitsPerPixel = 4;
			}
			else if(internalFormat == GL_COMPRESSED_RGBA_S3TC_DXT3_EXT || internalFormat == GL_COMPRESSED_RGBA_S3TC_DXT5_EXT)
			{
				retVal.bitsPerPixel = 8;
			}
			else assert(false);
		}
		
		return retVal;
	}
	
	private static bool isCompressedFormat(GLenum format)
	{
		import std.algorithm.comparison : among;
		return format.among(GL_COMPRESSED_RGB_S3TC_DXT1_EXT, GL_COMPRESSED_RGBA_S3TC_DXT3_EXT, GL_COMPRESSED_RGBA_S3TC_DXT5_EXT) != 0;
	}
}

enum DefaultTextureFormat : TextureFormat
{
	R		= TextureFormat(GL_RED,				GL_RED,				GL_UNSIGNED_BYTE,	8),
	RG		= TextureFormat(GL_RG,				GL_RG8,				GL_UNSIGNED_BYTE,	16),
	RGB		= TextureFormat(GL_RGB,				GL_RGB8,			GL_UNSIGNED_BYTE,	24),
	RGBA	= TextureFormat(GL_RGBA,			GL_RGBA8,			GL_UNSIGNED_BYTE,	32),
	RGBA16	= TextureFormat(GL_RGBA,			GL_RGBA16,			GL_UNSIGNED_SHORT,	64),
	Depth	= TextureFormat(GL_DEPTH_COMPONENT,	GL_DEPTH_COMPONENT,	GL_FLOAT,			32)
}

uint getMipmapsBufferLength(TextureFormat format, vec2ui resolution)
{
	import std.range : iota;
	import std.algorithm.iteration : map, sum;
	
	return
		getRequiredMipmapLevels(resolution)
		.iota()
		.map!(level => getMipmapLevelResolution(resolution, level))
		.map!(levelResolution => getTexelBufferLength(format, levelResolution))
		.sum;
}

uint getTexelBufferLength(TextureFormat format, vec2ui resolution)
{
	if(format.bufferFormatIsCompressed)
	{
		// S3TC uses 4x4 block compression
		resolution.x = max(resolution.x, 4);
		resolution.y = max(resolution.y, 4);
		
		assert(resolution.x % 4 == 0 && resolution.y % 4 == 0);
	}
	
	// Calc line in bits, convert to bytes before multiplying with height to avoid overflow
	return (resolution.x * format.bitsPerPixel / 8) * resolution.y;
}

vec2ui getMipmapLevelResolution(vec2ui baseResolution, uint level)
{
	assert(level < typeof(baseResolution.x).sizeof * 8);
	
	return componentMax(vec2ui(1, 1), vec2ui(baseResolution.x >> level, baseResolution.y >> level));
}

uint getRequiredMipmapLevels(vec2ui resolution)
{
	return max(resolution.x, resolution.y).higherPOT.getLog2 + 1;
}

Texture defaultTexture()
{
	static Texture texture;
	
	if(!texture.refCountedStore.isInitialized)
	{
		ubyte[] data = [
			255, 0, 255, 255,
			127, 0, 127, 255,
			127, 0, 127, 255,
			255, 0, 255, 255
		];
		texture = TextureManager.create(DefaultTextureFormat.RGBA, vec2ui(2, 2), data, "Default Texture");
	}
	return texture;
}

class Texture_Impl
{
	const
	{	
		package GLuint	handle;
		vec2ui			resolution;
		TextureFormat	format;
		string			name;
	}
	
	this(TextureFormat format, vec2ui resolution, const(void)[] buffer, string name = null)
	{
		import std.conv : text;

		handle = gl.genTexture();
		this.resolution = resolution;
		this.format = format;
		this.name = name ? name : handle.text;
		load(buffer);
	}

	~this()
	{
		gl.DeleteTextures(1, &handle);
	}
	
	// Determines if mipmaps are included based on buffer length. Generates mipmaps when not present.
	// Mipmaps are ordered high to low level in the buffer, so starting with the lowest resolution.
	void load(const(void)[] buffer)
	{
		const mipmapsLength = getMipmapsBufferLength(format, resolution);
		const bufferContainsMipmaps = buffer.length == mipmapsLength;
		
		assert(buffer.ptr == null || bufferContainsMipmaps || buffer.length == getTexelBufferLength(format, resolution));

		ScratchTextureUnit.makeActiveScratch(this);

		if(bufferContainsMipmaps)
		{
			import std.range : iota, retro;
			
			auto remainingBuffer = buffer;
			
			foreach(level; getRequiredMipmapLevels(resolution).iota.retro)
			{
				auto levelResolution = getMipmapLevelResolution(resolution, level);
				auto sliceLength = getTexelBufferLength(format, levelResolution);
				
				uploadMipmapLevel(levelResolution, level, remainingBuffer[0 .. sliceLength]);
				remainingBuffer = remainingBuffer[sliceLength .. $];
			}
			
			assert(remainingBuffer.length == 0);
		}
		else
		{
			uploadMipmapLevel(resolution, 0, buffer);
			gl.GenerateMipmap(GL_TEXTURE_2D);
		}
	}
	
	private void uploadMipmapLevel(vec2ui resolution, int level, const(void)[] buffer)
	{
		if(format.bufferFormatIsCompressed)
		{
			assert(format.internalFormat == format.bufferFormat);
			
			import std.conv : to;
			
			gl.CompressedTexImage2D(
				GL_TEXTURE_2D,
				level,
				format.internalFormat,
				resolution.x,
				resolution.y,
				0,
				buffer.length.to!GLsizei,
				buffer.ptr
			);
		}
		else
		{
			gl.TexImage2D(
				GL_TEXTURE_2D, 
				level, 
				format.internalFormat,
				resolution.x,
				resolution.y,
				0,
				format.bufferFormat,
				format.type,
				buffer.ptr
			);
		}
	}

	void[] downloadTexelBuffer(bool includeMipmaps = true)
	{
		// TODO:
		assert(includeMipmaps);
		assert(format.internalFormatIsCompressed);
		
		auto downloadFormat = format.asDownloadFormat;
		
		auto texelBuffer = new void[](getMipmapsBufferLength(downloadFormat, resolution));
		
		import std.range : iota, retro;
			
		auto remainingBuffer = texelBuffer;
		
		foreach(level; getRequiredMipmapLevels(resolution).iota.retro)
		{
			auto levelResolution = getMipmapLevelResolution(resolution, level);
			auto sliceLength = getTexelBufferLength(downloadFormat, levelResolution);
			
			import std.conv : to;
			gl.GetCompressedTextureImage(handle, level, remainingBuffer.length.to!GLsizei, remainingBuffer.ptr);
			remainingBuffer = remainingBuffer[sliceLength .. $];
		}
		
		return texelBuffer;
	}
}

private enum ScratchTextureUnit = TextureUnit(TextureUnit.Size-1);

struct TextureUnits
{
	static
	{
		// OpenGL Texture handles. Can't store TextureManager Handles, underlying texture can change.
		// Can't store Texture_Impl either, they can be destroyed by the TextureManager.
		private GLuint[TextureUnit.Size] units;
		// Ditto
		private GLuint[TextureUnit.Size] samplers;
		private size_t current = 0;
	}
}

private void makeActiveScratch(TextureUnit unit, Texture_Impl texture)
{
	// Ensure the scratch unit is active, or consecutive updates to
	// the same texture may fail if another unit is activated in the mean time
	unit.makeCurrent();
	unit.set(texture.handle, TextureUnits.samplers[unit.index]);
}

void set(TextureUnit unit, ref Texture texture, ref Sampler sampler)
{
	set(unit, TextureManager.getConcreteResource(texture).handle, SamplerManager.getConcreteResource(sampler).handle);
}

private void set(TextureUnit unit, GLuint textureHandle, GLuint samplerHandle)
{
	if(TextureUnits.units[unit.index] !is textureHandle)
	{
		unit.makeCurrent();
		//trace("Binding Texture ", texture.name, " to unit ", unit.index);
		gl.BindTexture(GL_TEXTURE_2D, textureHandle);
		TextureUnits.units[unit.index] = textureHandle;
	}
	
	if(TextureUnits.samplers[unit.index] !is samplerHandle)
	{
		gl.BindSampler(unit.index, samplerHandle);
		TextureUnits.samplers[unit.index] = samplerHandle;
	}
}

private void makeCurrent(TextureUnit unit)
{
	if(TextureUnits.current != unit.index)
	{
		//trace("Switching to texture unit ", unit.index);

		gl.ActiveTexture(GL_TEXTURE0 + unit.index);
		TextureUnits.current = unit.index;
	}
}