module kratos.ui.panel;

import derelict.freetype.ft;

import kratos.ecs;
import kgl3n;

import kratos.component.spatialpartitioning : SpatialPartitioning;
import kratos.component.transform : Transform;
import kratos.component.renderer : Renderer;

import kratos.graphics.renderablemesh;
import kratos.graphics.mesh;
import kratos.graphics.texture;

import kratos.resource.filesystem;
import kratos.resource.loader.renderstateloader;

alias UiComponentPartitioning = SpatialPartitioning!UiComponent;

public abstract class UiComponent : Component
{
	@ignore:

	protected @dependency Transform _transform;
	protected RenderableMesh _mesh;

	protected this()
	{
		_mesh = defaultRenderableMesh;
		scene.components.firstOrAdd!UiComponentPartitioning.register(this);
	}
	
	~this()
	{
		scene.components.first!UiComponentPartitioning.deregister(this);
	}
	
	private void initialize()
	{
		// For depth testing UI hierarchies.
		_transform.position.z = 0.001f;
	}
	
	final @property ref 
	{
		RenderableMesh mesh()
		{
			return _mesh;
		}
		
		Transform transform()
		{
			return _transform;
		}
	}
}

public final class Panel : UiComponent
{
	vec2 size; //TODO: Allow updating after initialization..
	vec2 offset;
	string renderState;

	this(){}

	this(vec2 size, vec2 offset, string renderState)
	{
		this.size = size;
		this.offset = offset;
		this.renderState = renderState;
	}
	
	private void initialize()
	{
		auto halfSize = size / 2;
	
		_mesh = renderableMesh
		(
			quad2D(-halfSize + offset, halfSize + offset),
			RenderStateLoader.get(renderState)
		);
	}
}

public final class TextPanel : UiComponent
{
	private @dependency Renderer renderer;
	
	private
	{
		string _text;

		vec2 _size;
		vec2 _offset;
		float _fontSize;
		string _font;
		string _renderState;

		Texture _texture;
		ubyte[] _texelBuffer;
		FT_Face _face; // Not sure what the overhead is here. Maybe these should be cached.
		immutable (ubyte)[] _faceBuffer;
		int _pixelSize;

		bool _requiresMeshUpdate;
		bool _requiresTextureUpdate;
		bool _requiresFontUpdate;
	}

	this(){};

	this(vec2 size, vec2 offset, float fontSize, string font, string renderState)
	{
		this.size = size;
		this.offset = offset;
		this.fontSize = fontSize;
		this.font = font;
		this.renderState = renderState;
	}
	
	@property
	{
		string text() const
		{
			return _text;
		}
		
		void text(string newText)
		{
			_text = newText;
			_requiresTextureUpdate = true;
		}

		vec2 size() const
		{
			return _size;
		}

		void size(vec2 newSize)
		{
			_size = newSize;
			_requiresMeshUpdate = true;
		}

		vec2 offset() const
		{
			return _offset;
		}

		void offset(vec2 newOffset)
		{
			_offset = newOffset;
			_requiresMeshUpdate = true;
		}

		float fontSize() const
		{
			return _fontSize;
		}

		void fontSize(float newFontSize)
		{
			_fontSize = newFontSize;
			_requiresTextureUpdate = true;
		}

		string font() const
		{
			return _font;
		}

		void font(string newFont)
		{
			_font = newFont;
			_requiresFontUpdate = true;
		}

		// I don't like having these as stirng properties..
		string renderState() const
		{
			return _renderState;
		}

		void renderState(string newRenderState)
		{
			_renderState = newRenderState;
			_requiresMeshUpdate = true;
		}
	}
	
	~this()
	{
		FT_Done_Face(_face);
	}
	
	void frameUpdate()
	{
		if(_requiresMeshUpdate)
		{
			_requiresMeshUpdate = false;
			_requiresTextureUpdate = true;

			auto screenResolution = renderer.screenResolution;
			
			auto texSize = vec2ui
			( // Size is in clip space, so -1 to 1. Therefore, multiply final size by 0.5.
				cast(uint)(screenResolution.x * size.x * 0.5f),
				cast(uint)(screenResolution.y * size.y * 0.5f)
			);
			
			_texture = TextureManager.create(DefaultTextureFormat.R, texSize, null, owner.name ~ " TextPanel");
			_texelBuffer = new ubyte[texSize.x * texSize.y];
			
			auto halfSize = size / 2;
			_mesh = renderableMesh
			(
				quad2D(-halfSize + offset, halfSize + offset, vec2(0, 1), vec2(1, 0)),
				RenderStateLoader.get(renderState)
			);

			_mesh.renderState.shader.uniforms["texture"] = _texture;
		}

		if(_requiresFontUpdate)
		{
			_requiresFontUpdate = false;
			_requiresTextureUpdate = true;

			//TODO: Error checks
			FT_Done_Face(_face);
			_faceBuffer = activeFileSystem.get!ubyte(font);
			FT_New_Memory_Face(freeType, _faceBuffer.ptr, cast(int)_faceBuffer.length, 0, &_face);
			// Size is in clip space, so -1 to 1. Therefore, multiply final size by 0.5.
			_pixelSize = cast(int)(renderer.screenResolution.y * fontSize * 0.5f);
			FT_Set_Pixel_Sizes(_face, _pixelSize, 0);
		}

		if(_requiresTextureUpdate)
		{
			_requiresTextureUpdate = false;
			renderTextToTexture();
		}
	}
	
	private void renderTextToTexture()
	{
		//TODO: Wrap
		//TODO: Scroll
		
		_texelBuffer[] = 0;
		auto position = vec2i(0, _pixelSize);
		
		foreach(dchar charCode; text)
		{
			auto glyphIndex = FT_Get_Char_Index(_face, charCode);
			FT_Load_Glyph(_face, glyphIndex, 0);
			
			if(_face.glyph.format != FT_GLYPH_FORMAT_BITMAP)
			{
				FT_Render_Glyph(_face.glyph, FT_RENDER_MODE_NORMAL);
			}
			
			auto bitmap = _face.glyph.bitmap;
			auto offset = vec2i(_face.glyph.bitmap_left, -_face.glyph.bitmap_top);
			auto resolution = TextureManager.getConcreteResource(_texture).resolution;
			
			foreach(y; 0..bitmap.rows)
			{
				foreach(x; 0..bitmap.width)
				{
					auto pixelPos = position + offset + vec2i(x, y);
					
					if(pixelPos.x < 0 || pixelPos.x >= resolution.x || pixelPos.y < 0 || pixelPos.y >= resolution.y)
					{
						continue;
					}
					
					_texelBuffer[pixelPos.x + pixelPos.y * resolution.x] = bitmap.buffer[x + y * bitmap.width];
				}
			}
			
			position += vec2i(_face.glyph.advance.x, _face.glyph.advance.y) / 64;
		}
		
		TextureManager.getConcreteResource(_texture).load(_texelBuffer);
	}
}

private __gshared FT_Library freeType;

shared static this()
{
	import derelict.util.exception : ShouldThrow;

	static ShouldThrow missingSymbolCallback(string symbolName)
	{
		import std.algorithm.searching : canFind;
	
		static skipNames = [
			"FT_Stream_OpenBzip2",
			"FT_Get_CID_Registry_Ordering_Supplement",
			"FT_Get_CID_Is_Internally_CID_Keyed",
			"FT_Get_CID_From_Glyph_Index"
		];
		
		return skipNames.canFind(symbolName) ? ShouldThrow.No : ShouldThrow.Yes;
	}

	DerelictFT.missingSymbolCallback = &missingSymbolCallback;
	DerelictFT.load();
	//TODO: Error checks
	FT_Init_FreeType(&freeType);
}

shared static ~this()
{
	FT_Done_FreeType(freeType);
	DerelictFT.unload();
}