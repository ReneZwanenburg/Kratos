module kratos.graphics.rendertarget;

import kgl3n;
import kratos.graphics.gl;
import kratos.graphics.texture;
import kratos.window;

final class RenderTarget
{
	public enum Buffer : GLenum
	{
		Color = GL_COLOR_BUFFER_BIT,
		Depth = GL_DEPTH_BUFFER_BIT,
		Stencil = GL_STENCIL_BUFFER_BIT,
		All = Buffer.Color | Buffer.Depth | Buffer.Stencil
	}

	ClearSettings clearSettings;
	alias clearSettings this;

	Buffer clearBuffers = Buffer.All;
	FrameBuffer frameBuffer;

	this()
	{
		frameBuffer = currentWindow.frameBuffer;
	}

	void apply()
	{
		frameBuffer.apply();
	}

	void clear()
	{
		assert(frameBuffer.active, "RenderTarget frameBuffer must be active before clearing, call apply on the RenderTarget to ensure it's FrameBuffer is active");
		clearSettings.apply();
		gl.Clear(clearBuffers);
	}
}

private struct ClearSettings
{
	private static ClearSettings currentClearSettings;

	vec4 clearColor;
	float clearDepth = 1;
	int clearStencil = 0;

	private void apply()
	{
		currentClearSettings.apply(this);
	}
	
	private void apply(ref const ClearSettings settings)
	{
		if(clearColor != settings.clearColor)
		{
			clearColor = settings.clearColor;
			gl.ClearColor(clearColor.r, clearColor.g, clearColor.b, clearColor.a);
		}
		if(clearDepth != settings.clearDepth)
		{
			clearDepth = settings.clearDepth;
			gl.ClearDepth(clearDepth);
		}
		if(clearStencil != settings.clearStencil)
		{
			clearStencil = settings.clearStencil;
			gl.ClearStencil(clearStencil);
		}
	}
}

final class FrameBuffer
{
	public static struct BufferDescription
	{
		string name;
		TextureFormat format;
	}

	private static FrameBuffer activeFrameBuffer;
	static this()
	{
		activeFrameBuffer = createScreenFrameBuffer(-1, -1);
	}

	private GLuint handle;
	private BufferDescription[] bufferDescriptions;
	private Texture[] textures;
	private vec2i _size;

	@property
	{
		vec2i size() const { return _size; }

		// Should be package(kratos)
		void size(vec2i size) nothrow
		{
			assert(handle == 0, "Non-screen FrameBuffer resizing not supported");
			this._size = size;
		}
	}

	public this(vec2i resolution, BufferDescription[] bufferDescriptions, bool createDepthRenderBufferIfMissing = true)
	{
		//TODO: generate FBO
		this._size = resolution;

		bool depthProvided = false;
		foreach(description; bufferDescriptions)
		{

		}
	}

	private this(vec2i size)
	{
		this.handle = 0;
		this.size = size;
	}

	private void apply()
	{
		activeFrameBuffer.apply(this);
	}

	private void apply(const FrameBuffer buffer)
	{
		if(handle != buffer.handle)
		{
			handle = buffer.handle;
			gl.BindFramebuffer(GL_FRAMEBUFFER, handle);
		}
		if(size != buffer.size)
		{
			size = buffer.size;
			gl.Viewport(0, 0, size.x, size.y);
		}
	}

	@property
	{
		bool active() const
		{
			return activeFrameBuffer.handle == handle;
		}
	}

	// Should be package(kratos)
	public static FrameBuffer createScreenFrameBuffer(int width, int height)
	{
		return new FrameBuffer(vec2i(width, height));
	}
}