﻿module kratos.resource.loader;

import kratos.resource.cache;
import kratos.resource.filesystem : activeFileSystem;


import kratos.graphics.texture;
import derelict.devil.il;

alias TextureCache = Cache!(Texture, string, loadTexture);

package Texture loadTexture(string name)
{
	auto handle = ilGenImage();
	scope(exit) ilDeleteImage(handle);
	ilBindImage(handle);

	import gl3n.linalg : vec2i;

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


private @property auto lowerCaseExtension(string path)
{
	import std.path : extension;
	import std.string : toLower;
	return path.extension.toLower();
}