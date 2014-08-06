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

	import gl3n.linalg;
	import kratos.graphics.gl;
	import kratos.resource.loader;
	import kratos.entity;
	import kratos.component.camera;
	import kratos.component.transform;
	import kratos.component.meshrenderer;
	import std.stdio;

	auto quadEntity = new Entity("quad");
	auto renderer = quadEntity.addComponent!MeshRenderer;
	auto quadTransform = quadEntity.getComponent!Transform;
	renderer.set(MeshCache.get("Meshes/Box.obj"), RenderStateCache.get("RenderStates/Test.renderstate"));

	auto cameraEntity = new Entity("Camera");
	Camera camera = cameraEntity.addComponent!Camera;
	auto cameraTransform = cameraEntity.getComponent!Transform;
	cameraTransform.position = vec3(0, 3, 4);
	camera.makeCurrent();

	Time.reset();
	while(!window.closeRequested)
	{
		window.updateInput();

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