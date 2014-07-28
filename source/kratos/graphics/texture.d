module kratos.graphics.texture;

import kratos.resource.resource;
import kratos.graphics.gl;
import gl3n.linalg;




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
	this(ubyte level)
	{
		assert(level <= maxAnisotropy);
		this._level = level;
	}

	alias level this;
	@property ubyte level()
	{
		return _level;
	}

	enum ubyte maxAnisotropy = 16;
	private ubyte _level = 1;
}

Sampler sampler(SamplerSettings settings)
{
	import kratos.resource.cache;

	alias SamplerCache = Cache!(Sampler, SamplerSettings);
	return SamplerCache.get!(
		(SamplerSettings settings)
		{
			auto sampler = Sampler(gl.genSampler, settings);
			gl.SamplerParameteri(sampler.handle, GL_TEXTURE_MIN_FILTER, settings.minFilter);
			gl.SamplerParameteri(sampler.handle, GL_TEXTURE_MAG_FILTER, settings.magFilter);
			gl.SamplerParameteri(sampler.handle, GL_TEXTURE_WRAP_S, settings.xWrap);
			gl.SamplerParameteri(sampler.handle, GL_TEXTURE_WRAP_T, settings.yWrap);
			gl.SamplerParameteri(sampler.handle, GL_TEXTURE_MAX_ANISOTROPY_EXT, settings.anisotropy);
			return sampler;
		}
	)(settings);
}

alias Sampler = Handle!Sampler_Impl;

private struct Sampler_Impl
{
	const:
	private GLuint		handle;
	SamplerSettings		settings;

	alias settings this;
}

struct SamplerSettings
{
	SamplerMinFilter	minFilter;
	SamplerMagFilter	magFilter;
	SamplerWrap			xWrap;
	SamplerWrap			yWrap;
	SamplerAnisotropy	anisotropy;
}

enum TextureFormat : GLenum
{
	R		= GL_RED,
	RGB		= GL_RGB,
	RGBA	= GL_RGBA
}

enum DefaultTextureCompression = false;

Texture texture(TextureFormat format, vec2i resolution, void[] data, bool compressed = DefaultTextureCompression)
{
	assert(pixelSize[format] * resolution.x * resolution.y == data.length);

	auto texture = Texture(gl.genTexture(), resolution, format, compressed);
	TextureUnit.makeActiveScratch(texture);
	gl.TexImage2D(
		GL_TEXTURE_2D, 
		0, 
		compressed ? compressedFormat[format] : format,
		resolution.x,
		resolution.y,
		0,
		format,
		GL_UNSIGNED_BYTE,
		data.ptr
	);

	return texture;
}

alias Texture = Handle!Texture_Impl;

struct Texture_Impl
{
	const:
	private GLuint	handle;
	vec2i			resolution;
	TextureFormat	format;
	bool			compressed;
}

private immutable GLenum[GLenum] compressedFormat;
private immutable size_t[GLenum] pixelSize;
static this()
{
	import std.traits;
	foreach(format; EnumMembers!TextureFormat)
	{
		final switch(format) with(TextureFormat)
		{
			case R:
				compressedFormat[format]	= GL_COMPRESSED_RED;
				pixelSize[format]			= 1;
			break;
			case RGB:
				compressedFormat[format]	= GL_COMPRESSED_RGB;
				pixelSize[format]			= 3;
			break;
			case RGBA:
				compressedFormat[format]	= GL_COMPRESSED_RGBA;
				pixelSize[format]			= 4;
			break;
		}
	}
}

public abstract final class TextureUnit
{
	static:

	private enum Size = 48;
	private enum ScratchUnit = Size - 1;
	private Texture[Size] units;
	private Sampler[Size] samplers;
	private size_t current = 0;

	private void makeActiveScratch(ref Texture texture)
	{
		// Ensure the scratch unit is active, or consecutive updates to
		// the same texture may fail if another unit is activated in the mean time
		setCurrentUnit(ScratchUnit);
		set(ScratchUnit, texture, samplers[ScratchUnit]);
	}

	void set(size_t unit, ref Texture texture, ref Sampler sampler)
	{
		if(units[unit] != texture)
		{
			setCurrentUnit(unit);
			gl.BindTexture(GL_TEXTURE_2D, texture.handle);
			units[unit] = texture;
		}

		if(samplers[unit] != sampler)
		{
			gl.BindSampler(unit, sampler.handle);
			samplers[unit] = sampler;
		}
	}

	private void setCurrentUnit(size_t unit)
	{
		assert(unit < Size);
		if(current != unit)
		{
			gl.ActiveTexture(GL_TEXTURE0 + unit);
			current = unit;
		}
	}
}