module kratos.main;

import kratos.time;
import kratos.window;
import kratos.resource.filesystem;

void main(string[] args)
{
	WindowProperties windowProperties = { };
	auto window = Window(windowProperties);
	import kratos.input : mouse;
	mouse.setGrabbed(true);

	import kratos.resource.loader;
	import kratos.resource.exporter.sceneexporter;
	import std.typecons : scoped;
	import kratos.scene;
	auto scene = scoped!Scene;
	loadScene("Scenes/Test.scene", scene);
	exportScene(scene, "Scenes/SerializedScene.scene");

	import std.experimental.logger;
	globalLogLevel = LogLevel.info;
	Time.reset();
	while(!window.closeRequested)
	{
		window.updateInput();
		import kratos.entity : dispatchFrameUpdate;
		dispatchFrameUpdate();

		import kratos.graphics.gl;
		gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		import kratos.component.meshrenderer;
		foreach(renderer; scene.getComponents!MeshRenderer)
		{
			renderer.draw();
		}

		window.swapBuffers();
		Time.update();
	}
}
