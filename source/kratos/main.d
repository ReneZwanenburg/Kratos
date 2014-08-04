module kratos.main;

import kratos.time;
import kratos.window;
import kratos.resource.filesystem;

void main(string[] args)
{
	activeFileSystem = new PackFileSystem("Kratos.assetpack");

	WindowProperties windowProperties = { };
	auto window = Window(windowProperties);
	//glfwSetKeyCallback(window, &glfwKeyCallback);

	import kratos.graphics.bo;
	import kratos.graphics.mesh;
	import kratos.graphics.shader;
	import gl3n.linalg;
	import kratos.graphics.shadervariable;
	import kratos.graphics.renderstate;
	import kratos.graphics.gl;
	import std.range;
	import kratos.component.meshrenderer;
	import kratos.graphics.texture;
	import kratos.resource.loader;
	import std.typecons;

	auto indices = ibo([
		0, 2, 1,
		1, 2, 3
	]);

	static struct P3T2
	{
		vec3 position;
		vec2 texCoord;
	}

	auto vertices = vbo([
		P3T2(vec3(-.5f,  .5f, 0), vec2(0, 0)),
		P3T2(vec3( .5f,  .5f, 0), vec2(1, 0)),
		P3T2(vec3(-.5f, -.5f, 0), vec2(0, 1)),
		P3T2(vec3( .5f, -.5f, 0), vec2(1, 1))
	]);

	auto quad = mesh(indices, vertices, toVertexAttributes!P3T2);

	auto prog = ProgramCache.get(["Shaders/Test.vert", "Shaders/Test.frag"]);

	scope renderer = new MeshRenderer(quad, RenderStateCache.get("RenderStates/Test.renderstate"));

	Time.reset();
	while(!window.closeRequested)
	{
		window.updateInput();

		import std.math;
		renderer.shader["scale"] = (sin(Time.total) + 1).to!float;


		import kratos.graphics.gl;
		gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		renderer.draw();

		window.swapBuffers();
		Time.update();
	}
}

/*
private extern(C) nothrow
{
	void glfwKeyCallback(GLFWwindow* window, int key, int scanCode, int action, int modifiers)
	{

	}
}
*/