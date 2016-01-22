module kratos.graphics.rendertarget;

import kgl3n;
import kratos.graphics.gl;
import kratos.graphics.texture;
import kratos.graphics.renderstate : DepthTest, DepthFunc;

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

	Buffer clearBuffers = Buffer.All;
	FrameBuffer frameBuffer;

	this(FrameBuffer frameBuffer)
	{
		assert(frameBuffer);
		this.frameBuffer = frameBuffer;
	}

	void bind()
	{
		frameBuffer.bind();
	}

	void clear()
	{
		static depthTestState = DepthTest(DepthFunc.LessOrEqual, false, true);
	
		assert(frameBuffer.active, "RenderTarget frameBuffer must be active before clearing, call apply on the RenderTarget to ensure it's FrameBuffer is active");
		clearSettings.apply();
		depthTestState.apply();
		gl.Clear(clearBuffers);
	}
}

private struct ClearSettings
{
	private static ClearSettings currentClearSettings;

	vec4 color;
	float depth = 1;
	int stencil = 0;

	private void apply()
	{
		currentClearSettings.apply(this);
	}
	
	private void apply(ref const ClearSettings settings)
	{
		if(color != settings.color)
		{
			color = settings.color;
			gl.ClearColor(color.r, color.g, color.b, color.a);
		}
		if(depth != settings.depth)
		{
			depth = settings.depth;
			gl.ClearDepth(depth);
		}
		if(stencil != settings.stencil)
		{
			stencil = settings.stencil;
			gl.ClearStencil(stencil);
		}
	}
}

//TODO: Make refcounted struct
final class FrameBuffer
{
	static struct BufferDescription
	{
		string name;
		TextureFormat format;
	}

	private static GLuint activeHandle;
	private static vec2ui activeViewportSize;
	//TODO: Constness
	private GLuint handle;
	private GLuint renderBufferHandle;
	private BufferDescription[] bufferDescriptions;
	private Texture[] textures;
	private vec2ui _size;

	@property
	{
		vec2ui size() const { return _size; }

		// Should be package(kratos)
		void size(vec2ui size) nothrow
		{
			assert(handle == 0, "Non-screen FrameBuffer resizing not supported");
			this._size = size;
		}
	}

	this(vec2ui resolution, BufferDescription[] bufferDescriptions, bool createDepthRenderBufferIfMissing = true)
	{
		gl.GenFramebuffers(1, &handle);
		this._size = resolution;
		this.bufferDescriptions = bufferDescriptions;

		bool depthProvided = false;
		GLenum colorAttachmentIndex = 0;
		enum maxColorAttachment = GL_COLOR_ATTACHMENT7;

		bind();

		foreach(description; bufferDescriptions)
		{
			auto format = description.format;

			auto tex = texture(format, resolution, null, description.name);
			textures ~= tex;

			GLenum attachment;
			//TODO: Support DepthStencil / Stencil formats
			if(format == DefaultTextureFormat.Depth)
			{
				assert(!depthProvided);
				depthProvided = true;
				attachment = GL_DEPTH_ATTACHMENT;
			}
			else
			{
				attachment = GL_COLOR_ATTACHMENT0 + colorAttachmentIndex++;
				assert(attachment <= maxColorAttachment);
			}

			gl.FramebufferTexture(GL_DRAW_FRAMEBUFFER, attachment, tex.handle, 0);
		}

		static immutable drawBuffers = [
			GL_COLOR_ATTACHMENT0,
			GL_COLOR_ATTACHMENT1,
			GL_COLOR_ATTACHMENT2,
			GL_COLOR_ATTACHMENT3,
			GL_COLOR_ATTACHMENT4,
			GL_COLOR_ATTACHMENT5,
			GL_COLOR_ATTACHMENT6,
			GL_COLOR_ATTACHMENT7
		];

		gl.DrawBuffers(colorAttachmentIndex, drawBuffers.ptr);

		if(!depthProvided && createDepthRenderBufferIfMissing)
		{
			gl.GenRenderbuffers(1, &renderBufferHandle);
			gl.BindRenderbuffer(GL_RENDERBUFFER, renderBufferHandle);
			gl.RenderbufferStorage(GL_RENDERBUFFER, GL_DEPTH_COMPONENT, resolution.x, resolution.y);
			gl.FramebufferRenderbuffer(GL_DRAW_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, GL_RENDERBUFFER, renderBufferHandle);
		}

		assert(gl.CheckFramebufferStatus(GL_DRAW_FRAMEBUFFER) == GL_FRAMEBUFFER_COMPLETE);
	}

	private this(vec2ui size)
	{
		this.handle = 0;
		this.size = size;
	}

	~this()
	{
		gl.DeleteFramebuffers(1, &handle);
		gl.DeleteRenderbuffers(1, &renderBufferHandle);
	}

	private void bind()
	{
		if(handle != activeHandle)
		{
			activeHandle = handle;
			gl.BindFramebuffer(GL_DRAW_FRAMEBUFFER, handle);
		}
		if(size != activeViewportSize)
		{
			activeViewportSize = size;
			gl.Viewport(0, 0, size.x, size.y);
		}
	}

	@property
	{
		bool active() const
		{
			return activeHandle == handle;
		}
	}

	Texture opIndex(string name)
	{
		import std.range : zip;

		foreach(description, texture; zip(bufferDescriptions, textures))
		{
			if(description.name == name) return texture;
		}

		assert(false);
	}

	// Should be package(kratos)
	public static FrameBuffer createScreenFrameBuffer(uint width, uint height)
	{
		return new FrameBuffer(vec2ui(width, height));
	}
}