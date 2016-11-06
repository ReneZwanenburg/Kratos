module kratos.resource.image;

import kgl3n.vector;
import kgl3n.math;
import kratos.graphics.gl;
import std.algorithm.comparison : among;
import std.algorithm.comparison : max;


struct ImageFormat
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

	public ImageFormat asCompressed() const
	{
		static GLenum[GLenum] internalFormatToCompressedMapping;
		if(internalFormatToCompressedMapping is null) internalFormatToCompressedMapping =
		[
			GL_RGB8:			GL_COMPRESSED_RGB_S3TC_DXT1_EXT,
			GL_SRGB8:			GL_COMPRESSED_SRGB_S3TC_DXT1_EXT,
			GL_RGBA8:			GL_COMPRESSED_RGBA_S3TC_DXT5_EXT,
			GL_SRGB8_ALPHA8:	GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT
		];

		ImageFormat retVal = this;
		if(auto compressedFormatPtr = retVal.internalFormat in internalFormatToCompressedMapping)
		{
			retVal.internalFormat = *compressedFormatPtr;
		}
		return retVal;
	}

	public ImageFormat asDownloadFormat() const
	{
		ImageFormat retVal = this;

		if(internalFormatIsCompressed)
		{
			retVal.bufferFormat = internalFormat;

			if(internalFormat.among(GL_COMPRESSED_RGB_S3TC_DXT1_EXT, GL_COMPRESSED_SRGB_S3TC_DXT1_EXT))
			{
				retVal.bitsPerPixel = 4;
			}
			else if(internalFormat.among(GL_COMPRESSED_RGBA_S3TC_DXT3_EXT,
										 GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT,
										 GL_COMPRESSED_RGBA_S3TC_DXT5_EXT,
										 GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT))
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
		return format.among(
							GL_COMPRESSED_RGB_S3TC_DXT1_EXT,
							GL_COMPRESSED_RGBA_S3TC_DXT3_EXT,
							GL_COMPRESSED_RGBA_S3TC_DXT5_EXT,
							GL_COMPRESSED_SRGB_S3TC_DXT1_EXT,
							GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT,
							GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT,
							GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT) != 0;
	}
}

enum StandardImageFormat : ImageFormat
{
	R		= ImageFormat(GL_RED,				GL_RED,				GL_UNSIGNED_BYTE,	8),
	RG		= ImageFormat(GL_RG,				GL_RG8,				GL_UNSIGNED_BYTE,	16),
	RGB		= ImageFormat(GL_RGB,				GL_RGB8,			GL_UNSIGNED_BYTE,	24),
	SRGB	= ImageFormat(GL_RGB,				GL_SRGB8,			GL_UNSIGNED_BYTE,	24),
	RGBA	= ImageFormat(GL_RGBA,				GL_RGBA8,			GL_UNSIGNED_BYTE,	32),
	SRGBA	= ImageFormat(GL_RGBA,				GL_SRGB8_ALPHA8,	GL_UNSIGNED_BYTE,	32),
	RGBA16	= ImageFormat(GL_RGBA,				GL_RGBA16,			GL_UNSIGNED_SHORT,	64),
	Depth	= ImageFormat(GL_DEPTH_COMPONENT,	GL_DEPTH_COMPONENT,	GL_FLOAT,			32)
}

struct Image
{
	private 
	{
		ubyte[] _data;
		string _name;
		ImageFormat _format;
		vec2ui _resolution;
		bool _dynamic, _containsMipmaps;
	}

	@property
	{
		bool containsMipmaps() const { return _containsMipmaps; }
		vec2ui resolution() const { return _resolution; }
		ImageFormat format() const { return _format; }
		const(ubyte)[] data() const { return _data; }
		ubyte[] mutableData() { assert(_dynamic); return _data; }
	}

	this(ImageFormat format, vec2ui resolution, string name = null)
	{
		this(format, resolution, null, name, false);
	}

	this(ImageFormat format, vec2ui resolution, immutable(ubyte)[] data, string name = null)
	{
		this(format, resolution, cast(ubyte[])data, name, false);
	}

	this(ImageFormat format, vec2ui resolution, ubyte[] data, string name = null, bool dynamic = true)
	{
		_data = data;
		_name = name.length ? name : "Unnamed Image";
		_format = format;
		_resolution = resolution;
		_dynamic = dynamic;

		// Determines if mipmaps are included based on buffer length
		// Mipmaps are ordered high to low level in the buffer, so starting with the lowest resolution
		// The order of these checks ensures a 1x1 image is marked as mipmaps-included
		// Null data allowed for conversion to Texture with default initialization
		// TODO: Decide what to do when slicing a null buffered image. Create or throw?
		if(data.ptr is null)
		{
			_containsMipmaps = false;
		}
		else if(data.length == mipmappedPixelBufferLength(format, resolution))
		{
			_containsMipmaps = true;
		}
		else if(data.length == pixelBufferLength(format, resolution))
		{
			_containsMipmaps = false;
		}
		else
		{
			import std.conv : text;
			throw new Exception("Incorrect buffer length: " ~ data.length.text);
		}
	}
}


uint mipmappedPixelBufferLength(ImageFormat format, vec2ui resolution)
{
	import std.range : iota;
	import std.algorithm.iteration : map, sum;

	return
		mipmapLevelCount(resolution)
		.iota()
		.map!(level => mipmapLevelResolution(resolution, level))
		.map!(levelResolution => pixelBufferLength(format, levelResolution))
		.sum;
}

uint pixelBufferLength(ImageFormat format, vec2ui resolution)
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

vec2ui mipmapLevelResolution(vec2ui baseResolution, uint level)
{
	assert(level < typeof(baseResolution.x).sizeof * 8);

	return componentMax(vec2ui(1, 1), vec2ui(baseResolution.x >> level, baseResolution.y >> level));
}

uint mipmapLevelCount(vec2ui resolution)
{
	return max(resolution.x, resolution.y).higherPOT.getLog2 + 1;
}
