module kratos.resource.loader.textureloader;

import kratos.resource.loader.internal;
import kratos.resource.cache;
import kratos.resource.resource;
import kratos.graphics.texture;
import derelict.devil.il;

alias TextureCache = Cache!(Texture, ResourceIdentifier, id => loadTexture(id));

private Texture loadTexture(ResourceIdentifier name)
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