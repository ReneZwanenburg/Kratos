module kratos.resource.format;

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
		import kratos.util : readFront;
	
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
}