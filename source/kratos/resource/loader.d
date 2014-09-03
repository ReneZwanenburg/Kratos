module kratos.resource.loader;

import kratos.resource.cache;
import kratos.resource.filesystem : activeFileSystem;

import vibe.data.json;

import kratos.graphics.texture;
import derelict.devil.il;

alias TextureCache = Cache!(Texture, string, loadTexture);

package Texture loadTexture(string name)
{
	auto handle = ilGenImage();
	scope(exit) ilDeleteImage(handle);
	ilBindImage(handle);

	import kgl3n.vector : vec2i;

	auto buffer = activeFileSystem.get(name);
	ilLoadL(imageExtensionFormat[name.lowerCaseExtension], buffer.ptr, buffer.length);

	auto dataPtr = ilGetData();
	auto resolution = vec2i(ilGetInteger(IL_IMAGE_WIDTH), ilGetInteger(IL_IMAGE_HEIGHT));
	auto format = ilTextureFormat[ilGetInteger(IL_IMAGE_FORMAT)];
	assert(ilGetInteger(IL_IMAGE_BYTES_PER_PIXEL) == bytesPerPixel[format]);
	assert(ilGetInteger(IL_IMAGE_TYPE) == IL_UNSIGNED_BYTE);

	return texture(format, resolution, dataPtr[0..resolution.x*resolution.y*bytesPerPixel[format]], name);
}

shared static this()
{
	DerelictIL.load();
	ilInit();
}

shared static ~this()
{
	ilShutDown();
	DerelictIL.unload();
}

//Sigh, for some reason DevIL doesn't provide this..
private immutable ILenum[string] imageExtensionFormat;
private immutable TextureFormat[ILint] ilTextureFormat;

static this()
{
	imageExtensionFormat = [
		".bmp"	: IL_BMP,
		".cut"	: IL_CUT,
		".dds"	: IL_DDS,
		".gif"	: IL_GIF,
		".ico"	: IL_ICO,
		".cur"	: IL_ICO,
		".jpg"	: IL_JPG,
		".jpe"	: IL_JPG,
		".jpeg"	: IL_JPG,
		".lbm"	: IL_LBM,
		".lif"	: IL_LIF,
		".mdl"	: IL_MDL,
		".mng"	: IL_MNG,
		".pcd"	: IL_PCD,
		".pcx"	: IL_PCX,
		".pic"	: IL_PIC,
		".png"	: IL_PNG,
		".pbm"	: IL_PNM,
		".pgm"	: IL_PNM,
		".ppm"	: IL_PNM,
		".pnm"	: IL_PNM,
		".psd"	: IL_PSD,
		".sgi"	: IL_SGI,
		".bw"	: IL_SGI,
		".rgb"	: IL_SGI,
		".rgba"	: IL_SGI,
		".tga"	: IL_TGA,
		".tif"	: IL_TIF,
		".tiff"	: IL_TIF,
		".wal"	: IL_WAL
	];

	ilTextureFormat = [
		IL_LUMINANCE	: TextureFormat.R,
		IL_RGB			: TextureFormat.RGB,
		IL_RGBA			: TextureFormat.RGBA
	];
}


import kratos.graphics.shader;

alias ShaderModuleCache = Cache!(ShaderModule, string, loadShaderModule);

package ShaderModule loadShaderModule(string name)
{
	auto buffer = activeFileSystem.get!char(name);
	return shaderModule(shaderExtensionType[name.lowerCaseExtension], buffer, name);
}

immutable ShaderModule.Type[string] shaderExtensionType;

static this()
{
	shaderExtensionType = [
		".vert": ShaderModule.Type.Vertex,
		".geom": ShaderModule.Type.Geometry,
		".frag": ShaderModule.Type.Fragment
	];
}


alias ProgramCache = Cache!(Program, string[], loadProgram);

package Program loadProgram(string[] modules)
{
	import std.algorithm : map;
	import std.conv : text;
	return program(modules.map!(a => ShaderModuleCache.get(a)), modules.text);
}


import kratos.graphics.renderstate;

alias RenderStateCache = Cache!(RenderState, string, loadRenderState);

package RenderState loadRenderState(string name)
{
	RenderState renderState;
	version(none)
	{
		auto json = parseJsonString(activeFileSystem.get!char(name));

		foreach(ref field; renderState.tupleof)
		{
			alias T = typeof(field);
			auto stateJson = json[T.stringof];
			if(stateJson.type == Json.Type.Undefined) continue;

			static if(is(T == Shader))
			{
				auto modules = deserializeJson!(string[])(stateJson["modules"]);
				import std.algorithm : sort;
				modules.sort();

				renderState.shader = Shader(ProgramCache.get(modules));

				auto uniforms = stateJson["uniforms"];
				if(uniforms.type != Json.Type.Undefined)
				{
					foreach(string name, value; uniforms)
					{
						if(value.type == Json.Type.String)
						{
							renderState.shader[name] = TextureCache.get(value.get!string);
						}
						else
						{
							auto uniform = renderState.shader[name];

							import kratos.graphics.gl;
							foreach(TypeBinding; GLTypes)
							{
								alias UT = TypeBinding.nativeType;
								if(TypeBinding.glType == uniform.type)
								{
									//TODO: Add support for uniform arrays and matrices
									import std.traits;
									import kgl3n.matrix;
									import kgl3n.vector;

									static if(is(UT == TextureUnit))
									{

									}
									/*
									else static if(isInstanceOf!(Vector, UT))
									{
										assert(value.type == Json.Type.Array);
										UT ut;
										ut.vector = deserializeJson!(typeof(ut.vector))(value);
										uniform = ut;
									}
									else static if(isInstanceOf!(Matrix, UT))
									{
										UT ut;
										ut.matrix = deserializeJson!(typeof(ut.matrix))(value);
										uniform = ut;
									}
									*/
									else
									{
										uniform = deserializeJson!(UT)(value);
									}
								}
							}
						}
					}
				}
			}
			else
			{
				field = deserializeJson!T(stateJson);
			}
		}
	}

	return renderState;
}


import kratos.graphics.mesh;

alias MeshCache = Cache!(Mesh, string, loadMesh);

Mesh loadMesh(string name)
{
	auto extension = name.lowerCaseExtension;
	auto data = activeFileSystem.get(name);

	if(name.lowerCaseExtension == ".ksm")
	{
		return loadMeshKSM(data);
	}
	else
	{
		version(KratosDisableAssimp)
		{
			assert(false, "Assimp support has been disabled, enable to load non-ksm meshes");
		}
		else
		{
			return loadMeshAssimp(data, name);
		}
	}
}

private Mesh loadMeshKSM(immutable void[] data)
{
	assert(false, "Not implemented yet");
}

version(KratosDisableAssimp) {}
else
{
	import derelict.assimp3.assimp;

	static this()
	{
		DerelictASSIMP3.load();
	}

	static ~this()
	{
		DerelictASSIMP3.unload();
	}

	private Mesh loadMeshAssimp(immutable void[] data, string extension)
	{
		import std.string;
		import std.exception;
		import kgl3n.vector;
		import kgl3n.matrix;
		import std.array;

		auto scene = aiImportFileFromMemory(
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
			extension.toStringz
		);

		enforce(scene, "Error while loading scene");
		scope(exit) aiReleaseImport(scene);

		static struct VertexFormat
		{
			vec3 position;
			vec3 normal;
			vec3 tangent;
			vec2 texCoord;
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


private @property auto lowerCaseExtension(string path)
{
	import std.path : extension;
	import std.string : toLower;
	return path.extension.toLower();
}