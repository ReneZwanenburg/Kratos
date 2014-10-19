﻿module kratos.window;

import derelict.glfw3.glfw3;
import std.exception : enforce, assumeWontThrow;
import kratos.input;
import vibe.data.serialization : optional;

enum WindowProperties unittestWindowProperties = { visible: false, debugContext: true };

struct WindowProperties
{
	@optional:
	int		width			= 800;
	int		height			= 600;
	string	title			= "Kratos Application";
	bool	fullScreen		= false;

	bool	visible			= true;
	bool	decorated		= true;

	int		msaa			= 0;
	bool	sRGB			= false;
	int		refreshRate		= 60;
	bool	debugContext	= false;
	bool	vSync			= true;
}



struct Window
{
	@disable this();
	@disable this(this);

	const	WindowProperties	properties;
	private	GLFWwindow*			_handle;

	this(WindowProperties properties)
	{
		this.properties = properties;
		with(properties)
		{
			glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
			glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
			glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

			glfwWindowHint(GLFW_RESIZABLE,				false);
			glfwWindowHint(GLFW_VISIBLE,				visible);
			glfwWindowHint(GLFW_DECORATED,				decorated);
			glfwWindowHint(GLFW_SAMPLES,				msaa);
			glfwWindowHint(GLFW_SRGB_CAPABLE,			sRGB);
			glfwWindowHint(GLFW_OPENGL_DEBUG_CONTEXT,	debugContext);
			glfwWindowHint(GLFW_REFRESH_RATE,			refreshRate);

			this._handle = glfwCreateWindow(
				width, height,
				title.ptr,
				fullScreen ? glfwGetPrimaryMonitor() : null,
				null
			);
			enforce(this._handle, "Window creation failed");
		}

		glfwMakeContextCurrent(_handle);
		import derelict.opengl3.gl3 : DerelictGL3;
		DerelictGL3.reload();

		glfwSetFramebufferSizeCallback(_handle, (_1, _2, _3) { assert(false, "Window resizing not supported"); });
		glfwSwapInterval(properties.vSync);

		_activeProperties = properties;

		mouse = new Mouse(this);
		keyboard = new Keyboard(this);
	}

	~this()
	{
		keyboard = null;
		mouse = null;
		glfwDestroyWindow(_handle);
	}

	void updateInput()
	{
		glfwPollEvents();
		mouse.update();
		keyboard.update();
	}

	void swapBuffers()
	{
		glfwSwapBuffers(_handle);
	}

	@property
	{
		bool closeRequested()
		{
			return !!glfwWindowShouldClose(_handle);
		}

		package GLFWwindow* handle()
		{
			return _handle;
		}
	}

	static
	{
		private WindowProperties _activeProperties;
		const(WindowProperties) activeProperties()
		{
			return _activeProperties;
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