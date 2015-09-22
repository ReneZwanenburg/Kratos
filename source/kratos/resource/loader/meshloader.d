module kratos.resource.loader.meshloader;

import kratos.resource.loader.internal;
import kratos.resource.cache;
import kratos.resource.resource;
import kratos.graphics.mesh;
import kratos.util : readFront;

alias MeshCache = Cache!(Mesh, ResourceIdentifier, id => loadMesh(id));

private Mesh loadMesh(ResourceIdentifier name)
{
	auto extension = name.lowerCaseExtension;
	auto data = activeFileSystem.get(name);

	if(extension == ".ksm")
	{
		auto mesh = loadMeshKratos(data);
		mesh.id = name;
		return mesh;
	}
	else
	{
		auto mesh = loadMeshAssimp(data, extension);
		mesh.id = name;
		return mesh;
	}
}

private Mesh loadMeshKratos(immutable (void)[] data)
{
	import kratos.graphics.shadervariable : VertexAttributes;
	import kratos.graphics.bo;

	auto vertexAttributes = data.readFront!VertexAttributes;
	auto vertexBufferByteLength = data.readFront!size_t;
	auto indexType = data.readFront!IndexType;
	auto indexBufferByteLength = data.readFront!size_t;
	return Mesh(
		IBO(data[vertexBufferByteLength .. $], indexType),
		VBO(data[0 .. vertexBufferByteLength], vertexAttributes)
	);
}

/////////
version(KratosDisableAssimp)
{
	private Mesh loadMeshAssimp(immutable void[] data, string extension)
	{
		assert(false, "Assimp mesh loading has been disabled. Build Kratos with Assimp support to load non-ksm meshes");
	}
}
else
{
	import derelict.assimp3.assimp;
	
	private Mesh loadMeshAssimp(immutable void[] data, string extension)
	{
		import std.string;
		import std.exception;
		import kgl3n.vector;
		import kgl3n.matrix;
		import std.array;
		
		auto scene = aiImportFileFromMemory(
			data.ptr,
			cast(uint)data.length,
			aiProcess_CalcTangentSpace		|
			aiProcess_JoinIdenticalVertices	|
			aiProcess_Triangulate			|
			aiProcess_GenSmoothNormals		|
			aiProcess_PreTransformVertices	|
			aiProcess_ImproveCacheLocality	|
			aiProcess_FindInvalidData		|
			//aiProcess_GenUVCoords			|
			aiProcess_FindInstances,
			extension.toStringz
			);
		
		enforce(scene, "Error while loading scene");
		scope(exit) aiReleaseImport(scene);
		
		static struct VertexFormat
		{
			vec3 position;
			vec3 normal;
			vec3 tangent;
			vec2 texCoord0;
		}
		
		Appender!(VertexFormat[])	vertices;
		Appender!(uint[])			indices;
		foreach(meshIndex; 0..scene.mNumMeshes)
		{
			auto mesh = scene.mMeshes[meshIndex];
			
			foreach(vertIndex; 0..mesh.mNumVertices)
			{
				auto vert		= mesh.mVertices[vertIndex];
				auto normal		= mesh.mNormals[vertIndex];
				auto tangent	= mesh.mTangents[vertIndex];
				auto texCoord	= mesh.mTextureCoords[0][vertIndex];
				
				vertices ~= VertexFormat(
					vec3(vert.x,		vert.y,			vert.z),
					vec3(normal.x,		normal.y,		normal.z).normalized,
					vec3(tangent.x,		tangent.y,		tangent.z).normalized,
					vec2(texCoord.x,	texCoord.y),
					);
			}
			
			foreach(faceIndex; 0..mesh.mNumFaces)
			{
				auto face = mesh.mFaces[faceIndex];
				auto faceIndices = face.mIndices[0..face.mNumIndices];
				assert(faceIndices.length == 3);
				indices.put(faceIndices);
			}
			
		}
		
		import kratos.graphics.bo;
		if(vertices.data.length < ushort.max)
		{
			import std.conv;
			return Mesh(IBO(indices.data.to!(ushort[])), VBO(vertices.data));
		}
		else
		{
			return Mesh(IBO(indices.data), VBO(vertices.data));
		}
	}
}
