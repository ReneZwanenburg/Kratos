module kratos.resource.loader.textureloader;

import kratos.resource.loader.internal;
import kratos.resource.cache;
import kratos.resource.resource;
import kratos.graphics.texture;
import derelict.devil.il;
import kgl3n.vector : vec2ui;
import kratos.resource.format : KratosTexture;

alias TextureCache = Cache!(Texture, ResourceIdentifier, id => loadTexture(id));

public Texture loadTexture(ResourceIdentifier name, bool compress = false)
{
	auto buffer = activeFileSystem.get(name);
	
	auto extension = name.lowerCaseExtension;
	
	if(extension == ".kst")
	{
		return loadTextureKst(name, buffer, compress);
	}
	else
	{
		return loadTextureIl(name, buffer, extension, compress);
	}
}

private Texture loadTextureKst(string name, const(void)[] buffer, bool compress)
{
	//TODO: Update format based on compression
	
	auto ksm = KratosTexture.fromBuffer(buffer);
	
	return texture
	(
		KratosTexture.getTextureFormat(ksm.format),
		ksm.resolution,
		ksm.texelBuffer,
		name
	);
}

private Texture loadTextureIl(string name, const(void)[] buffer, string extension, bool compress)
{
	//TODO: Update format based on compression
	
	auto handle = ilGenImage();
	scope(exit) ilDeleteImage(handle);
	ilBindImage(handle);
	ilLoadL(imageExtensionFormat[name.lowerCaseExtension], buffer.ptr, cast(uint)buffer.length);
	
	auto dataPtr = ilGetData();
	auto resolution = vec2ui(ilGetInteger(IL_IMAGE_WIDTH), ilGetInteger(IL_IMAGE_HEIGHT));
	auto format = ilTextureFormat[ilGetInteger(IL_IMAGE_FORMAT)];
	assert(ilGetInteger(IL_IMAGE_BYTES_PER_PIXEL) == format.bytesPerPixel);
	assert(ilGetInteger(IL_IMAGE_TYPE) == format.type);
	
	return texture(format, resolution, dataPtr[0..resolution.x*resolution.y*format.bytesPerPixel], name);
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
private immutable TextureFormat[ILint] ilTextureFormat;

shared static this()
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
		".lbm"	: IL_ILBM,
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
		IL_LUMINANCE	: DefaultTextureFormat.R,
		IL_RGB			: DefaultTextureFormat.RGB,
		IL_RGBA			: DefaultTextureFormat.RGBA
	];
}
