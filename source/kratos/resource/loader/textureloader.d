module kratos.resource.loader.textureloader;

import kratos.graphics.texture;
import kratos.resource.manager;
import kratos.resource.loader.imageloader;

alias TextureLoader = Loader!(Texture_Impl, (string name) => new Texture_Impl(ImageLoader.get(name)), true);