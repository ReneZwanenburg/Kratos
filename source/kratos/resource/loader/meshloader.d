module kratos.resource.loader.meshloader;
 
import kratos.resource.manager;
import kratos.resource.loader.internal;
import kratos.graphics.mesh;
import kratos.util : readFront;


alias MeshLoader = Loader!(Mesh_Impl, loadMesh, true);


Mesh_Impl loadMesh(string name)
{
	auto data = activeFileSystem.get(name);
	
	// This is a nasty little hack to work around a DMD ICE
	// when building in release mode, current version is 2.071.2
	static kratosMeshLoader = &loadMeshKratos;

	auto mesh = data.extension == "ksm"
		? kratosMeshLoader(data)
		: loadMeshAssimp(data);
	
	mesh.name = name;
	
	return mesh;
}

private Mesh_Impl loadMeshKratos(RawFileData data)
{
	import kratos.resource.format : KratosMesh;
	import kratos.graphics.bo;
	
	auto importedMesh = KratosMesh.fromBuffer(data.data);

	return new Mesh_Impl(
		IBO(importedMesh.indexBuffer, importedMesh.indexType),
		VBO(importedMesh.vertexBuffer, importedMesh.vertexAttributes)
	);
}

/////////
version(KratosDisableAssimp)
{
	private Mesh_Impl loadMeshAssimp(RawFileData data)
	{
		assert(false, "Assimp mesh loading has been disabled. Build Kratos with Assimp support to load non-ksm meshes");
	}
}
else
{
	import derelict.assimp3.assimp;
	
	private Mesh_Impl loadMeshAssimp(RawFileData data)
	{
		import std.string;
		import std.exception;
		import kgl3n.vector;
		import kgl3n.matrix;
		import std.array;
		import std.conv : to;
		
		auto properties = aiCreatePropertyStore();
		scope(exit) aiReleasePropertyStore(properties);
		aiSetImportPropertyFloat(properties, AI_CONFIG_PP_GSN_MAX_SMOOTHING_ANGLE, 45f);
		
		auto scene = aiImportFileFromMemoryWithProperties(
			data.data.ptr,
			data.data.length.to!uint,
			aiProcess_CalcTangentSpace		|
			aiProcess_JoinIdenticalVertices	|
			aiProcess_Triangulate			|
			aiProcess_GenSmoothNormals		|
			aiProcess_PreTransformVertices	|
			aiProcess_ImproveCacheLocality	|
			aiProcess_FindInvalidData		|
			aiProcess_FindInstances,
			data.extension.toStringz,
			properties
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
				auto tangent	= mesh.mTangents ? mesh.mTangents[vertIndex] : aiVector3D(0, 0, 0);
				auto texCoord	= mesh.mTextureCoords[0] ? mesh.mTextureCoords[0][vertIndex] : aiVector3D(0, 0, 0);
				
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
				if(faceIndices.length < 3) continue;
				assert(faceIndices.length == 3);
				indices.put(faceIndices);
			}
			
		}
		
		import kratos.graphics.bo;
		if(vertices.data.length < ushort.max)
		{
			import std.conv;
			return new Mesh_Impl(IBO(indices.data.to!(ushort[])), VBO(vertices.data));
		}
		else
		{
			return new Mesh_Impl(IBO(indices.data), VBO(vertices.data));
		}
	}
}
