module kratos.graphics.texture;

import kratos.resource.resource;
import kratos.graphics.gl;
import kgl3n.vector;
import kgl3n.math;
//import std.experimental.logger;

import vibe.data.serialization : optional, byName;

public import kratos.graphics.textureunit;


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

Sampler sampler(SamplerSettings settings)
{
	import kratos.resource.cache;

	auto createSampler = 
		(SamplerSettings settings)
		{
			auto sampler = Sampler(gl.genSampler, settings);
			gl.SamplerParameteri(sampler.handle, GL_TEXTURE_MIN_FILTER, settings.minFilter);
			gl.SamplerParameteri(sampler.handle, GL_TEXTURE_MAG_FILTER, settings.magFilter);
			gl.SamplerParameteri(sampler.handle, GL_TEXTURE_WRAP_S, settings.xWrap);
			gl.SamplerParameteri(sampler.handle, GL_TEXTURE_WRAP_T, settings.yWrap);
			gl.SamplerParameteri(sampler.handle, GL_TEXTURE_MAX_ANISOTROPY_EXT, settings.anisotropy);
			return sampler;
	};

	alias SamplerCache = Cache!(Sampler, SamplerSettings, createSampler);
	return SamplerCache.get(settings);
}

Sampler defaultSampler()
{
	return sampler(SamplerSettings.init);
}

alias Sampler = Handle!Sampler_Impl;

private struct Sampler_Impl
{
	const:
	private GLuint		handle;
	SamplerSettings		settings;

	alias settings this;

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
	//RG		= TextureFormat(GL_RG,				GL_RG8,				GL_UNSIGNED_BYTE,	16),
	RGB		= TextureFormat(GL_RGB,				GL_RGB8,			GL_UNSIGNED_BYTE,	24),
	RGBA	= TextureFormat(GL_RGBA,			GL_RGBA8,			GL_UNSIGNED_BYTE,	32),
	RGBA16	= TextureFormat(GL_RGBA,			GL_RGBA16,			GL_UNSIGNED_SHORT,	64),
	Depth	= TextureFormat(GL_DEPTH_COMPONENT,	GL_DEPTH_COMPONENT,	GL_FLOAT,			32)
}

// Determines if mipmaps are included based on buffer length. Generates mipmaps when not present.
Texture texture(TextureFormat format, vec2ui resolution, const(void)[] buffer, string name = null)
{
	const mipmapsLength = getMipmapsBufferLength(format, resolution);
	const bufferContainsMipmaps = buffer.length == mipmapsLength;
	
	assert(buffer.ptr == null || bufferContainsMipmaps || buffer.length == getMipmapBufferLength(format, resolution));

	const handle = gl.genTexture();
	auto texture = Texture(handle, resolution, format, name ? name : handle.text);
	ScratchTextureUnit.makeActiveScratch(texture);

	if(bufferContainsMipmaps)
	{
		import std.range : iota, retro;
		
		auto remainingBuffer = buffer;
		
		foreach(level; getRequiredMipMapLevels(resolution).iota.retro)
		{
			auto levelResolution = getMipmapLevelResolution(resolution, level);
			auto sliceLength = getMipmapBufferLength(format, levelResolution);
			
			uploadMipmapLevel(format, levelResolution, level, remainingBuffer[0 .. sliceLength]);
			remainingBuffer = remainingBuffer[sliceLength .. $];
		}
		
		assert(remainingBuffer.length == 0);
	}
	else
	{
		uploadMipmapLevel(format, resolution, 0, buffer);
		gl.GenerateMipmap(GL_TEXTURE_2D);
	}

	return texture;
}

void[] downloadTextureBuffer(Texture texture, bool includeMipmaps = true)
{
	// TODO:
	assert(includeMipmaps);
	assert(texture.format.internalFormatIsCompressed);
	
	auto downloadFormat = texture.format.asDownloadFormat;
	
	auto texelBuffer = new void[](getMipmapsBufferLength(downloadFormat, texture.resolution));
	
	import std.range : iota, retro;
		
	auto remainingBuffer = texelBuffer;
	
	foreach(level; getRequiredMipMapLevels(texture.resolution).iota.retro)
	{
		auto levelResolution = getMipmapLevelResolution(texture.resolution, level);
		auto sliceLength = getMipmapBufferLength(downloadFormat, levelResolution);
		
		import std.conv : to;
		gl.GetCompressedTextureImage(texture.handle, level, remainingBuffer.length.to!GLsizei, remainingBuffer.ptr);
		remainingBuffer = remainingBuffer[sliceLength .. $];
	}
	
	return texelBuffer;
}

private void uploadMipmapLevel(TextureFormat format, vec2ui resolution, int level, const(void)[] buffer)
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

uint getMipmapsBufferLength(TextureFormat format, vec2ui resolution)
{
	const requiredMipMapLevels = getRequiredMipMapLevels(resolution);
	
	uint mipmapsLengthInBytes = 0;
	
	foreach(level; 0 .. requiredMipMapLevels)
	{
		mipmapsLengthInBytes += getMipmapBufferLength(format, resolution);
		resolution = getNextMipmapLevelResolution(resolution);
	}
	
	return mipmapsLengthInBytes;
}

uint getMipmapBufferLength(TextureFormat format, vec2ui resolution)
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

private vec2ui getMipmapLevelResolution(vec2ui baseResolution, uint level)
{
	foreach(_; 0..level) baseResolution = getNextMipmapLevelResolution(baseResolution);
	return baseResolution;
}

private vec2ui getNextMipmapLevelResolution(vec2ui resolution)
{
	resolution /= 2;
	resolution.x = max(resolution.x, 1);
	resolution.y = max(resolution.y, 1);
	return resolution;
}

private uint getRequiredMipMapLevels(vec2ui resolution)
{
	return max(resolution.x, resolution.y).higherPOT.getLog2 + 1;
}

Texture defaultTexture()
{
	static Texture texture;
	static bool initialized = false;
	
	if(!initialized)
	{
		ubyte[] data = [
			255, 0, 255, 255,
			127, 0, 127, 255,
			127, 0, 127, 255,
			255, 0, 255, 255
		];
		texture = .texture(DefaultTextureFormat.RGBA, vec2ui(2, 2), data, "Default Texture");
		initialized = true;
	}
	return texture;
}

alias Texture = Handle!Texture_Impl;

struct Texture_Impl
{
	const:
	package GLuint	handle;
	vec2ui			resolution;
	TextureFormat	format;
	string			name;

	~this()
	{
		gl.DeleteTextures(1, &handle);
	}
}

private enum ScratchTextureUnit = TextureUnit(TextureUnit.Size-1);

struct TextureUnits
{
	static
	{
		private Texture[TextureUnit.Size] units;
		private Sampler[TextureUnit.Size] samplers;
		private size_t current = 0;
	}
}

private void makeActiveScratch(TextureUnit unit, ref Texture texture)
{
	// Ensure the scratch unit is active, or consecutive updates to
	// the same texture may fail if another unit is activated in the mean time
	unit.makeCurrent();
	unit.set(texture, TextureUnits.samplers[unit.index]);
}

void set(TextureUnit unit, ref Texture texture, ref Sampler sampler)
{
	if(TextureUnits.units[unit.index] !is texture)
	{
		unit.makeCurrent();
		//trace("Binding Texture ", texture.name, " to unit ", unit.index);
		gl.BindTexture(GL_TEXTURE_2D, texture.handle);
		TextureUnits.units[unit.index] = texture;
	}
	
	if(TextureUnits.samplers[unit.index] !is sampler)
	{
		gl.BindSampler(unit.index, sampler.handle);
		TextureUnits.samplers[unit.index] = sampler;
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