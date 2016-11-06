module kratos.resource.loader.textureloader;

import kratos.resource.manager;
import kratos.resource.loader.internal;
import kratos.graphics.texture;
import derelict.devil.il;
import kgl3n.vector : vec2ui;
import kratos.resource.format : KratosTexture;
import std.typecons : tuple;

alias TextureLoader = Loader!(Texture_Impl, (string name) => loadTexture(name), true);

Texture_Impl loadTexture(string name, uint lod = 0, bool forceCompression = false)
{
	auto data = activeFileSystem.get(name);
	
	if(data.extension == "kst")
	{
		return loadTextureKst(data, lod, forceCompression);
	}
	else
	{
		return loadTextureIl(data, lod, forceCompression);
	}
}

private Texture_Impl loadTextureKst(RawFileData data, uint lod, bool forceCompression)
{
	auto ksm = KratosTexture.fromBuffer(data.data);
	
	auto format = KratosTexture.getImageFormat(ksm.format);
	if(forceCompression)
	{
		format = format.asCompressed;
	}
	
	assert(ksm.flags & KratosTexture.Flags.MipmapsIncluded || lod == 0);
	
	import std.algorithm.comparison : min;
	lod = min(lod, mipmapLevelCount(ksm.resolution)-1);
	
	auto lodResolution = mipmapLevelResolution(ksm.resolution, lod);
	auto lodBufferLength = mipmappedPixelBufferLength(format, lodResolution);
	
	return new Texture_Impl
	(Image(
		format,
		lodResolution,
		cast(immutable(ubyte)[])ksm.texelBuffer[0 .. lodBufferLength],
		data.name
	));
}

private Texture_Impl loadTextureIl(RawFileData data, uint lod, bool forceCompression)
{
	assert(lod == 0);

	auto handle = ilGenImage();
	scope(exit) ilDeleteImage(handle);
	ilBindImage(handle);
	import std.conv : to;
	ilLoadL(imageExtensionFormat[data.extension], data.data.ptr, data.data.length.to!uint);
	
	auto dataPtr = ilGetData();
	auto resolution = vec2ui(ilGetInteger(IL_IMAGE_WIDTH), ilGetInteger(IL_IMAGE_HEIGHT));
	
	import std.path : extension;
	auto nameExtension = data.name.extension;
	auto assumeSrgb = nameExtension.length == 0 || nameExtension == ".d";
	
	ImageFormat format = ilTextureFormat[tuple(ilGetInteger(IL_IMAGE_FORMAT).to!uint, assumeSrgb)];
	
	if(forceCompression)
	{
		format = format.asCompressed;
	}
	
	assert(ilGetInteger(IL_IMAGE_BYTES_PER_PIXEL)*8 == format.bitsPerPixel);
	assert(ilGetInteger(IL_IMAGE_TYPE) == format.type);
	
	return new Texture_Impl(Image(format, resolution, dataPtr[0..resolution.x*resolution.y*format.bitsPerPixel/8], data.name));
}

shared static this()
{
	DerelictIL.load();
	ilInit();

	ilEnable(IL_ORIGIN_SET);
	ilOriginFunc(IL_ORIGIN_LOWER_LEFT);
}

shared static ~this()
{
	ilShutDown();
	DerelictIL.unload();
}

//Sigh, for some reason DevIL doesn't provide this..
private immutable ILenum[string] imageExtensionFormat;
private immutable ImageFormat[typeof(tuple(IL_LUMINANCE, true))] ilTextureFormat;

shared static this()
{
	imageExtensionFormat = [
		"bmp"	: IL_BMP,
		"cut"	: IL_CUT,
		"dds"	: IL_DDS,
		"gif"	: IL_GIF,
		"ico"	: IL_ICO,
		"cur"	: IL_ICO,
		"jpg"	: IL_JPG,
		"jpe"	: IL_JPG,
		"jpeg"	: IL_JPG,
		"lbm"	: IL_ILBM,
		"lif"	: IL_LIF,
		"mdl"	: IL_MDL,
		"mng"	: IL_MNG,
		"pcd"	: IL_PCD,
		"pcx"	: IL_PCX,
		"pic"	: IL_PIC,
		"png"	: IL_PNG,
		"pbm"	: IL_PNM,
		"pgm"	: IL_PNM,
		"ppm"	: IL_PNM,
		"pnm"	: IL_PNM,
		"psd"	: IL_PSD,
		"sgi"	: IL_SGI,
		"bw"	: IL_SGI,
		"rgb"	: IL_SGI,
		"rgba"	: IL_SGI,
		"tga"	: IL_TGA,
		"tif"	: IL_TIF,
		"tiff"	: IL_TIF,
		"wal"	: IL_WAL
	];

	ilTextureFormat = [
		tuple(IL_LUMINANCE, false)	: StandardImageFormat.R,
		tuple(IL_RGB, false)		: StandardImageFormat.RGB,
		tuple(IL_RGBA, false)		: StandardImageFormat.RGBA,
		tuple(IL_LUMINANCE, true)	: StandardImageFormat.R,
		tuple(IL_RGB, true)			: StandardImageFormat.SRGB,
		tuple(IL_RGBA, true)		: StandardImageFormat.SRGBA
	];
}
