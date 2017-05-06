module kratos.resource.format;

import kratos.util : readFront;
import std.range.primitives : put;

struct KratosMesh
{
	import kratos.graphics.shadervariable : VertexAttributes;
	import kratos.graphics.bo : IndexType;
	
	VertexAttributes	vertexAttributes;
	uint				vertexBufferLength;
	IndexType			indexType;
	uint				indexBufferLength;
	const(void)[]		vertexBuffer;
	const(void)[]		indexBuffer;
	
	public static KratosMesh fromBuffer(immutable(void)[] data)
	{
		auto retVal = KratosMesh
		(
			data.readFront!VertexAttributes,
			data.readFront!uint,
			data.readFront!IndexType,
			data.readFront!uint
		);
		
		assert(retVal.vertexBufferLength + retVal.indexBufferLength == data.length);
		
		retVal.vertexBuffer = data[0 .. retVal.vertexBufferLength];
		retVal.indexBuffer = data[retVal.vertexBufferLength .. $];
		
		return retVal;
	}

	public void toBuffer(OutputRange)(auto ref OutputRange range)
	{
		put(range, vertexAttributes);
		put(range, vertexBufferLength);
		put(range, indexType);
		put(range, indexBufferLength);
		put(range, vertexBuffer);
		put(range, indexBuffer);
	}
}

struct KratosTexture
{
	import kgl3n.vector : vec2ui;
	import kratos.resource.image : ImageFormat, StandardImageFormat, mipmappedPixelBufferLength, pixelBufferLength;
	
	enum Format : uint
	{
		R,
		RGB,
		SRGB,
		RGBA,
		SRGBA,
		RGB_DXT1,
		SRGB_DXT1,
		RGBA_DXT3,
		SRGBA_DXT3,
		RGBA_DXT5,
		SRGBA_DXT5
	}
	
	enum Flags : uint
	{
		MipmapsIncluded = 1 << 0 // Contains precomputed mipmaps, starting with the lowest-resolution mipmap.
	}
	
	vec2ui resolution;
	Format format;
	Flags flags;
	const(void)[] texelBuffer;
	
	public static KratosTexture fromBuffer(const(void)[] data)
	{
		auto retVal = KratosTexture
		(
			data.readFront!vec2ui,
			data.readFront!Format,
			data.readFront!Flags
		);
		
		auto format = getImageFormat(retVal.format);
		assert(data.length == mipmappedPixelBufferLength(format, retVal.resolution) || data.length == pixelBufferLength(format, retVal.resolution));
		retVal.texelBuffer = data;
		
		return retVal;
	}
	
	public void toBuffer(OutputRange)(OutputRange range)
	{
		put(range, resolution);
		put(range, format);
		put(range, flags);
		put(range, texelBuffer);
	}
	
	public static ImageFormat getImageFormat(Format format)
	{
		import kratos.graphics.gl;
	
		static immutable formatTable = 
		[
			StandardImageFormat.R,
			StandardImageFormat.RGB,
			StandardImageFormat.SRGB,
			StandardImageFormat.RGBA,
			StandardImageFormat.SRGBA,
			ImageFormat(GL_COMPRESSED_RGB_S3TC_DXT1_EXT, GL_COMPRESSED_RGB_S3TC_DXT1_EXT, GL_UNSIGNED_BYTE, 4),
			ImageFormat(GL_COMPRESSED_SRGB_S3TC_DXT1_EXT, GL_COMPRESSED_SRGB_S3TC_DXT1_EXT, GL_UNSIGNED_BYTE, 4),
			ImageFormat(GL_COMPRESSED_RGBA_S3TC_DXT3_EXT, GL_COMPRESSED_RGBA_S3TC_DXT3_EXT, GL_UNSIGNED_BYTE, 8),
			ImageFormat(GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT, GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT, GL_UNSIGNED_BYTE, 8),
			ImageFormat(GL_COMPRESSED_RGBA_S3TC_DXT5_EXT, GL_COMPRESSED_RGBA_S3TC_DXT5_EXT, GL_UNSIGNED_BYTE, 8),
			ImageFormat(GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT, GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT, GL_UNSIGNED_BYTE, 8)
		];
		
		return formatTable[format];
	}
}