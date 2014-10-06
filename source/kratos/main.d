module kratos.main;

import kratos.time;
import kratos.window;
import kratos.resource.filesystem;

void main(string[] args)
{
	activeFileSystem = new PackFileSystem("Kratos.assetpack");

	WindowProperties windowProperties = { };
	auto window = Window(windowProperties);

	import kgl3n.vector;
	import kratos.graphics.gl;
	import kratos.resource.loader;
	import kratos.entity;
	import kratos.component.camera;
	import kratos.component.transform;
	import kratos.component.meshrenderer;
	import kratos.component.simplemovement;
	import kratos.input;
	import std.stdio;

	mouse.setGrabbed(true);

	auto quadEntity = loadEntity("Entities/Test.entity");
	auto cameraEntity = loadEntity("Entities/Camera.entity");

	Time.reset();
	while(!window.closeRequested)
	{
		window.updateInput();

		dispatchFrameUpdate();

		import kratos.graphics.gl;
		gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		quadEntity.getComponent!MeshRenderer.draw();

		window.swapBuffers();
		Time.update();
	}
}
