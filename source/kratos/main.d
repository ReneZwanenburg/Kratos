module kratos.main;

import derelict.glfw3.glfw3;
import derelict.opengl3.gl3 : DerelictGL3;

import std.exception : enforce, assumeWontThrow;

shared static this()
{
	DerelictGL3.load();

	DerelictGLFW3.load();
	glfwSetErrorCallback(&glfwErrorCallback);
	enforce(glfwInit(), "GLFW3 initialization failed");
}

shared static ~this()
{
	glfwTerminate();
	DerelictGLFW3.unload();

	DerelictGL3.unload();
}

void main(string[] args)
{
	glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
	glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
	glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);

	glfwWindowHint(GLFW_RESIZABLE, false);

	auto window = glfwCreateWindow(800, 600, "Kratos", null, null);
	enforce(window, "Window creation failed");
	scope(exit) glfwDestroyWindow(window);

	glfwMakeContextCurrent(window);
	DerelictGL3.reload();

	while(!glfwWindowShouldClose(window))
	{
		glfwPollEvents();

		glfwSwapBuffers(window);
	}
}

private extern(C) void glfwErrorCallback(int errorCode, const(char)* description) nothrow
{
	import std.stdio : writefln;
	import std.conv : text;

	assumeWontThrow(writefln("GLFW Error %s: %s", errorCode, description.text));
	assert(false);
}