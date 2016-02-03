module kratos.resource.loader.sceneloader;

import kratos.resource.loader.internal;
import kratos.resource.cache;
import kratos.resource.resource;
import kratos.ecs;
import kratos.graphics.mesh;
import kvibe.data.json;
import derelict.assimp3.assimp;
import kratos.graphics.renderstate;
import kratos.resource.loader.renderstateloader;
import kgl3n.vector;
//import std.experimental.logger;

public Scene loadScene(ResourceIdentifier name)
{
	auto extension = name.lowerCaseExtension;
	import std.algorithm : among;
	if(extension.among(".scene", ".entity"))
	{
		return loadSceneKratos(name);
	}
	else
	{
		return loadSceneAssimp(name);
	}
}

private Scene loadSceneKratos(ResourceIdentifier name)
{
	return Scene.deserialize(loadJson(name), &loadJson);
}

version(KratosDisableAssimp)
{
	private void loadSceneAssimp(ResourceIdentifier name, Scane scene)
	{
		assert(false, "Assimp support has been disabled, enable to load non-ksm meshes");
	}
}
else
{
	private Scene loadSceneAssimp(ResourceIdentifier name)
	{
		import std.path : baseName;
		auto scene = new Scene(name.baseName);
		auto data = activeFileSystem.get(name);
		
		import std.string : toStringz;
		import std.exception : enforce;
		import std.container : Array;
		import kgl3n.matrix;
		import kratos.component.transform;
		import kratos.component.camera;
		import kratos.component.meshrenderer;
		import std.algorithm : map;

		//info("Importing Scene ", name);

		auto importedScene = aiImportFileFromMemory(
			data.ptr,
			cast(uint)data.length,
			aiProcess_CalcTangentSpace		|
			aiProcess_JoinIdenticalVertices	|
			aiProcess_Triangulate			|
			aiProcess_GenSmoothNormals		|
			aiProcess_ImproveCacheLocality	|
			aiProcess_FindInvalidData		|
			aiProcess_GenUVCoords			|
			aiProcess_FindInstances
			,
			name.lowerCaseExtension.toStringz
			);
		
		enforce(importedScene, "Error while loading scene");
		scope(exit) aiReleaseImport(importedScene);

		//info("Importing ", importedScene.mNumMeshes, " meshes");
		auto loadedMeshes = Array!Mesh(importedScene.mMeshes[0..importedScene.mNumMeshes].map!(a => loadMesh(a)));
		//info("Importing ", importedScene.mNumMaterials, " materials");
		auto loadedMaterials = Array!RenderState(importedScene.mMaterials[0..importedScene.mNumMaterials].map!(a => loadMaterial(a)));

		
		void loadNode(const aiNode* node, Transform parent)
		{
			auto entity = scene.createEntity(node.mName.data[0 .. node.mName.length].idup);
			//info("Importing Node ", entity.name);
			auto transform = entity.components.add!Transform;
			transform.parent = parent;
			transform.localTransformation = Transformation.fromMatrix(*(cast(mat4*)&node.mTransformation));
			
			foreach(meshIndex; 0..node.mNumMeshes)
			{
				auto meshRenderer = entity.components.add!MeshRenderer;
				import kratos.graphics.renderablemesh : renderableMesh;
				meshRenderer.mesh = renderableMesh(loadedMeshes[node.mMeshes[meshIndex]], loadedMaterials[importedScene.mMeshes[node.mMeshes[meshIndex]].mMaterialIndex]);
			}
			
			foreach(childIndex; 0..node.mNumChildren)
			{
				loadNode(node.mChildren[childIndex], transform);
			}
		}
		
		loadNode(importedScene.mRootNode, null);
		
		return scene;
	}
}

private Mesh loadMesh(const aiMesh* mesh)
{
	//info("Importing Mesh '", mesh.mName.data[0..mesh.mName.length], '\'');

	import kratos.graphics.shadervariable;
	VertexAttributes attributes;
	
	attributes.add(VertexAttribute.fromAggregateType!vec3("position"));
	if(mesh.mNormals)		attributes.add(VertexAttribute.fromAggregateType!vec3("normal"));
	if(mesh.mTangents)		attributes.add(VertexAttribute.fromAggregateType!vec3("tangent"));
	if(mesh.mBitangents)	attributes.add(VertexAttribute.fromAggregateType!vec3("bitangent"));
	foreach(i, texCoordChannel; mesh.mTextureCoords)
	{
		import std.conv : text;
		if(texCoordChannel)	attributes.add(VertexAttribute.fromBasicType!float(mesh.mNumUVComponents[i], "texCoord" ~ i.text));
	}
	
	float[] buffer;
	assert(attributes.totalByteSize % float.sizeof == 0);
	buffer.reserve(attributes.totalByteSize / float.sizeof * mesh.mNumVertices);
	
	foreach(vertexIndex; 0..mesh.mNumVertices)
	{
		static void appendVector(ref float[] buffer, aiVector3D vector, size_t numElements = 3)
		{
			auto vectorSlice = (&vector.x)[0..numElements];
			buffer ~= vectorSlice;
		}
		
		appendVector(buffer, mesh.mVertices[vertexIndex]);
		if(mesh.mNormals)		appendVector(buffer, mesh.mNormals[vertexIndex]);
		if(mesh.mTangents)		appendVector(buffer, mesh.mTangents[vertexIndex]);
		if(mesh.mBitangents)	appendVector(buffer, mesh.mBitangents[vertexIndex]);
		foreach(channelIndex, texCoordChannel; mesh.mTextureCoords)
		{
			if(texCoordChannel)	appendVector(buffer, texCoordChannel[vertexIndex], mesh.mNumUVComponents[channelIndex]);
		}
	}
	
	import kratos.graphics.bo;
	auto vbo = VBO(cast(void[])buffer, attributes);
	
	IBO createIndices(T)()
	{
		T[] indices;
		indices.reserve(mesh.mNumFaces * 3);
		foreach(i; 0..mesh.mNumFaces)
		{
			auto face = mesh.mFaces[i];
			assert(face.mNumIndices == 3);
			foreach(index; face.mIndices[0 .. face.mNumIndices])
			{
				import std.conv;
				indices ~= index.to!T;
			}
		}
		
		return IBO(indices);
	}
	
	auto ibo = mesh.mNumVertices < ushort.max ? createIndices!ushort : createIndices!uint;
	return Mesh(ibo, vbo);
}

private RenderState loadMaterial(const aiMaterial* material)
{
	import kratos.resource.loader.textureloader;
	RenderState renderState = RenderStateCache.get("RenderStates/DefaultImport.renderstate");

	static struct TextureProperties
	{
		string uniformName;
		aiTextureType textureType;
		string defaultTexture = "Textures/White.png";
	}

	foreach(properties; [
		TextureProperties("diffuseTexture", aiTextureType_DIFFUSE),
		TextureProperties("specularTexture", aiTextureType_SPECULAR),
		TextureProperties("emissiveTexture", aiTextureType_EMISSIVE, "Textures/Black.png")
	])
	{
		aiString path;
		if(aiGetMaterialTexture(material, properties.textureType, 0, &path) == aiReturn_SUCCESS)
		{
			renderState.shader[properties.uniformName] = TextureCache.get(path.data[0..path.length].idup);
		}
		else
		{
			renderState.shader[properties.uniformName] = TextureCache.get(properties.defaultTexture);
		}
	}

	auto ambientColor = vec4(1, 1, 1, 1);
	aiGetMaterialColor(material, AI_MATKEY_COLOR_AMBIENT, 0, 0, cast(aiColor4D*)&ambientColor);
	auto diffuseColor = vec4(1, 1, 1, 1);
	aiGetMaterialColor(material, AI_MATKEY_COLOR_DIFFUSE, 0, 0, cast(aiColor4D*)&diffuseColor);
	auto specularColor = vec4(1, 1, 1, 1);
	aiGetMaterialColor(material, AI_MATKEY_COLOR_SPECULAR, 0, 0, cast(aiColor4D*)&specularColor);
	auto emissiveColor = vec4(0, 0, 0, 0);
	aiGetMaterialColor(material, AI_MATKEY_COLOR_EMISSIVE, 0, 0, cast(aiColor4D*)&emissiveColor);

	renderState.shader["ambientColor"] = ambientColor.rgb;
	renderState.shader["diffuseColor"] = diffuseColor;
	renderState.shader["specularColor"] = specularColor;
	renderState.shader["emissiveColor"] = emissiveColor.rgb;

	return renderState;
}

shared static this()
{
	DerelictASSIMP3.load();
}

shared static ~this()
{
	DerelictASSIMP3.unload();
}
