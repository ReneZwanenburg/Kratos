module kratos.window;

import derelict.glfw3.glfw3;
import std.exception : enforce, assumeWontThrow;

enum WindowProperties unittestWindowProperties = { visible: false, debugContext: true };

struct WindowProperties
{
	int		width			= 800;
	int		height			= 600;
	string	title			= "Kratos Application";
	bool	fullScreen		= false;

	bool	resizable		= false;
	bool	visible			= true;
	bool	decorated		= true;

	int		msaa			= 0;
	bool	sRGB			= false;
	int		refreshRate		= 60;
	bool	debugContext	= false;
}



struct Window
{
	@disable this();
	@disable this(this);

	const	WindowProperties	properties;
	private	GLFWwindow*			handle;

	this(WindowProperties properties)
	{
		this.properties = properties;
		with(properties)
		{
			glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
			glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
			glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

			glfwWindowHint(GLFW_RESIZABLE,				resizable);
			glfwWindowHint(GLFW_VISIBLE,				visible);
			glfwWindowHint(GLFW_DECORATED,				decorated);
			glfwWindowHint(GLFW_SAMPLES,				msaa);
			glfwWindowHint(GLFW_SRGB_CAPABLE,			sRGB);
			glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT,	debugContext);
			glfwWindowHint(GLFW_REFRESH_RATE,			refreshRate);

			this.handle = glfwCreateWindow(
				width, height,
				title.ptr,
				fullScreen ? glfwGetPrimaryMonitor() : null,
				null
			);
			enforce(this.handle, "Window creation failed");
		}

		glfwMakeContextCurrent(handle);
		import derelict.opengl3.gl3 : DerelictGL3;
		DerelictGL3.reload();

		//TODO: hmm, do we really want to do that here?
		import kratos.graphics.gl;
		glfwSetFramebufferSizeCallback(handle, (_, width, height) => assumeWontThrow(gl.Viewport(0, 0, width, height)));
	}

	~this()
	{
		glfwDestroyWindow(handle);
	}

	void updateInput()
	{
		glfwPollEvents();
	}

	void swapBuffers()
	{
		glfwSwapBuffers(handle);
	}

	@property
	{
		bool closeRequested()
		{
			return !!glfwWindowShouldClose(handle);
		}
	}
}


shared static this()
{
	DerelictGLFW3.load();
	glfwSetErrorCallback(&glfwErrorCallback);
	enforce(glfwInit(), "GLFW3 initialization failed");
}

shared static ~this()
{
	glfwTerminate();
	DerelictGLFW3.unload();
}

private extern(C) nothrow void glfwErrorCallback(int errorCode, const(char)* description)
{
	import std.stdio : writefln;
	import std.conv : text;
	
	assumeWontThrow(writefln("GLFW Error %s: %s", errorCode, description.text));
	assert(false);
}