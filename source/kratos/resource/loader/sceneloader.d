module kratos.resource.loader.sceneloader;

import kratos.resource.loader.internal;
import kratos.resource.cache;
import kratos.resource.resource;
import kratos.scene;
import kratos.entity;
import kratos.graphics.mesh;
import vibe.data.json;
import derelict.assimp3.assimp;

public Scene loadScene(ResourceIdentifier name, Scene scene = null)
{
	auto extension = name.lowerCaseExtension;
	import std.algorithm : among;
	if(extension.among(".scene", ".entity"))
	{
		return loadSceneKratos(name, scene);
	}
	else
	{
		return loadSceneAssimp(name, scene);
	}
}

private Scene loadSceneKratos(ResourceIdentifier name, Scene scene)
{
	auto json = parseJsonString(activeFileSystem.get!char(name));
	
	if(scene is null)
	{
		scene = new Scene(json["name"].get!string);
	}
	
	loadSceneKratos(json, scene);
	return scene;
}

private void loadSceneKratos(Json json, Scene scene)
{
	if(json["entities"].type == Json.Type.array)
	{
		foreach(entity; json["entities"])
		{
			if(entity.type == Json.Type.string)
			{
				loadSceneKratos(entity.get!ResourceIdentifier, scene);
			}
			else if(entity.type == Json.Type.object)
			{
				loadSceneKratos(entity, scene);
			}
			else
			{
				assert(false, "Not an Entity, invalid JSON type");
			}
		}
	}
	else if(json["components"].type == Json.Type.array)
	{
		scene.addEntity(json.deserializeJson!Entity);
	}
	else
	{
		assert(false);
	}
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
	private Scene loadSceneAssimp(ResourceIdentifier name, Scene scene)
	{
		import std.path : baseName;
		if(scene is null)
		{
			scene = new Scene(name.baseName);
		}
		
		auto data = activeFileSystem.get(name);
		
		import std.string : toStringz;
		import std.exception : enforce;
		import kgl3n.vector;
		import kgl3n.matrix;
		import kratos.component.transform;
		import kratos.component.camera;
		import kratos.component.meshrenderer;
		
		auto importedScene = aiImportFileFromMemory(
			data.ptr,
			data.length,
			aiProcess_CalcTangentSpace		|
			aiProcess_JoinIdenticalVertices	|
			aiProcess_Triangulate			|
			aiProcess_GenSmoothNormals		|
			aiProcess_PreTransformVertices	|
			aiProcess_ImproveCacheLocality	|
			aiProcess_FindInvalidData		|
			//aiProcess_GenUVCoords			|
			aiProcess_FindInstances,
			name.lowerCaseExtension.toStringz
			);
		
		enforce(importedScene, "Error while loading scene");
		scope(exit) aiReleaseImport(importedScene);
		
		void loadNode(const aiNode* node, Transform parent)
		{
			auto entity = scene.createEntity(node.mName.data[0 .. node.mName.length].idup);
			auto transform = entity.addComponent!Transform;
			transform.parent = parent;
			//TODO: load transformation matrix
			
			foreach(meshIndex; 0..node.mNumMeshes)
			{
				auto mesh = importedScene.mMeshes[node.mMeshes[meshIndex]];
				auto meshRenderer = entity.addComponent!MeshRenderer;
				
				import kratos.graphics.shadervariable;
				VertexAttributes attributes;
				
				attributes.add(VertexAttribute.fromAggregateType!vec3("position"));
				if(mesh.mNormals)		attributes.add(VertexAttribute.fromAggregateType!vec3("normal"));
				if(mesh.mTangents)		attributes.add(VertexAttribute.fromAggregateType!vec3("tangent"));
				if(mesh.mBitangents)	attributes.add(VertexAttribute.fromAggregateType!vec3("binormal"));
				foreach(i, texCoordChannel; mesh.mTextureCoords)
				{
					import std.conv : text;
					if(texCoordChannel)	attributes.add(VertexAttribute.fromBasicType!float(mesh.mNumUVComponents[i], "texCoord" ~ i.text));
				}
				
				//TODO: Avoid mesh copies
				float[] buffer;
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
						if(texCoordChannel)	appendVector(buffer, mesh.mTextureCoords[channelIndex][vertexIndex], mesh.mNumUVComponents[channelIndex]);
					}
				}
				
				import kratos.graphics.bo;
				auto vbo = VBO(buffer, attributes);
				
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
				auto loadedMesh = Mesh(ibo, vbo);
				
				entity.addComponent!MeshRenderer().mesh = loadedMesh;
				//TODO: Load material
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

shared static this()
{
	DerelictASSIMP3.load();
}

shared static ~this()
{
	DerelictASSIMP3.unload();
}
