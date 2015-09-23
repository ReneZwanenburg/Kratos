module kratos.graphics.texture;

import kratos.resource.resource;
import kratos.graphics.gl;
import kgl3n.vector;
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
	GLenum	format;
	GLenum	internalFormatUncompressed;
	GLenum	internalFormatCompressed;
	GLenum	type;
	uint	bytesPerPixel;
}

enum DefaultTextureFormat : TextureFormat
{
	R		= TextureFormat(GL_RED,				GL_RED,				GL_COMPRESSED_RED,	GL_UNSIGNED_BYTE,	1),
	//RG		= TextureFormat(GL_RG,				GL_RG8,				GL_COMPRESSED_RG,	GL_UNSIGNED_BYTE,	2),
	RGB		= TextureFormat(GL_RGB,				GL_RGB8,			GL_COMPRESSED_RGB,	GL_UNSIGNED_BYTE,	3),
	RGBA	= TextureFormat(GL_RGBA,			GL_RGBA8,			GL_COMPRESSED_RGBA,	GL_UNSIGNED_BYTE,	4),
	RGBA16	= TextureFormat(GL_RGBA,			GL_RGBA16,			GL_COMPRESSED_RGBA,	GL_UNSIGNED_SHORT,	8),
	Depth	= TextureFormat(GL_DEPTH_COMPONENT,	GL_DEPTH_COMPONENT,	GL_DEPTH_COMPONENT,	GL_FLOAT,			4)
}

enum DefaultTextureCompression = false;

Texture texture(TextureFormat format, vec2i resolution, void[] data, string name = null, bool compressed = DefaultTextureCompression)
{
	assert(data.ptr == null || format.bytesPerPixel * resolution.x * resolution.y == data.length);

	const handle = gl.genTexture();
	auto texture = Texture(handle, resolution, format, name ? name : handle.text, compressed);
	ScratchTextureUnit.makeActiveScratch(texture);

	gl.TexImage2D(
		GL_TEXTURE_2D, 
		0, 
		compressed ? format.internalFormatCompressed : format.internalFormatUncompressed,
		resolution.x,
		resolution.y,
		0,
		format.format,
		format.type,
		data.ptr
	);

	gl.GenerateMipmap(GL_TEXTURE_2D);

	return texture;
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
		texture = .texture(DefaultTextureFormat.RGBA, vec2i(2, 2), data, "Default Texture", false);
		initialized = true;
	}
	return texture;
}

alias Texture = Handle!Texture_Impl;

struct Texture_Impl
{
	const:
	package GLuint	handle;
	vec2i			resolution;
	TextureFormat	format;
	string			name;
	bool			compressed;

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