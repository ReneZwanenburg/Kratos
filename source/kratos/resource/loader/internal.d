module kratos.resource.loader.internal;


public import kratos.resource.filesystem;

package:

import derelict.devil.il;
import kratos.graphics.texture;

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
immutable ILenum[string] imageExtensionFormat;
immutable TextureFormat[ILint] ilTextureFormat;

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

immutable ShaderModule.Type[string] shaderExtensionType;

static this()
{
	shaderExtensionType = [
		".vert": ShaderModule.Type.Vertex,
		".geom": ShaderModule.Type.Geometry,
		".frag": ShaderModule.Type.Fragment
	];
}


import derelict.assimp3.assimp;

static this()
{
	DerelictASSIMP3.load();
}

static ~this()
{
	DerelictASSIMP3.unload();
}

@property auto lowerCaseExtension(string path)
{
	import std.path : extension;
	import std.string : toLower;
	return path.extension.toLower();
}