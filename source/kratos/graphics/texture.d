module kratos.graphics.texture;

import kratos.graphics.gl;
import kgl3n.vector;
//import std.experimental.logger;
import kratos.resource.manager;

import vibe.data.serialization : optional, byName;

public import kratos.graphics.textureunit;
public import kratos.resource.image;


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
		texture = TextureManager.create(Image(StandardImageFormat.RGBA, vec2ui(2, 2), data, "Default Texture"));
	}
	return texture;
}

class Texture_Impl
{
	package const GLuint handle;
	
	private Image _image;

	inout(Image) image() inout { return _image; }

	this(Image image)
	{
		handle = gl.genTexture();
		_image = image;

		reload();
	}

	~this()
	{
		gl.DeleteTextures(1, &handle);
	}
	
	// Generates mipmaps when not present
	void reload()
	{
		ScratchTextureUnit.makeActiveScratch(this);

		if(_image.containsMipmaps)
		{
			import std.range : iota, retro;
			
			auto remainingBuffer = _image.data;
			
			foreach(level; mipmapLevelCount(_image.resolution).iota.retro)
			{
				auto levelResolution = mipmapLevelResolution(_image.resolution, level);
				auto sliceLength = pixelBufferLength(_image.format, levelResolution);
				
				uploadMipmapLevel(levelResolution, level, remainingBuffer[0 .. sliceLength]);
				remainingBuffer = remainingBuffer[sliceLength .. $];
			}
			
			assert(remainingBuffer.length == 0);
		}
		else
		{
			uploadMipmapLevel(_image.resolution, 0, _image.data);
			gl.GenerateMipmap(GL_TEXTURE_2D);
		}
	}
	
	private void uploadMipmapLevel(vec2ui resolution, int level, const(ubyte)[] buffer)
	{
		auto format = _image.format;

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
		assert(_image.format.internalFormatIsCompressed);
		
		auto downloadFormat = _image.format.asDownloadFormat;
		
		auto texelBuffer = new ubyte[](mipmappedPixelBufferLength(downloadFormat, _image.resolution));
		
		import std.range : iota, retro;
			
		auto remainingBuffer = texelBuffer;
		
		foreach(level; mipmapLevelCount(_image.resolution).iota.retro)
		{
			auto levelResolution = mipmapLevelResolution(_image.resolution, level);
			auto sliceLength = pixelBufferLength(downloadFormat, levelResolution);
			
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