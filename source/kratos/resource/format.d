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
	import kratos.graphics.texture : TextureFormat, DefaultTextureFormat;
	
	enum Format : uint
	{
		R,
		RGB,
		RGBA
	}
	
	enum Flags : uint
	{
		Compressed = 1 << 0 // Stored with S3TC applied. Not yet supported.
	}
	
	vec2ui resolution;
	Format format;
	uint flags;
	const(void)[] pixelBuffer;
	
	public static KratosTexture fromBuffer(const(void)[] data)
	{
		auto retVal = KratosTexture
		(
			data.readFront!vec2ui,
			data.readFront!Format,
			data.readFront!uint
		);
		
		auto format = getTextureFormat(retVal.format);
		assert(retVal.resolution.x * retVal.resolution.y * format.bytesPerPixel == data.length);
		retVal.pixelBuffer = data;
		
		return retVal;
	}
	
	public void toBuffer(OutputRange)(OutputRange range)
	{
		put(range, resolution);
		put(range, format);
		put(range, flags);
		put(range, pixelBuffer);
	}
	
	public static TextureFormat getTextureFormat(Format format)
	{
		static immutable formatTable = 
		[
			DefaultTextureFormat.R,
			DefaultTextureFormat.RGB,
			DefaultTextureFormat.RGBA
		];
		
		return formatTable[format];
	}
}