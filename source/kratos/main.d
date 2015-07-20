module kratos.main;

import kratos.time;
import kratos.window;
import kratos.resource.filesystem;
import kratos.component.registrations;

version(KratosCustomMain) { }
else
{
	void main(string[] args)
	{
		import kratos.configuration;

		WindowProperties windowProperties = Configuration.defaultWindowProperties;
		auto window = Window(windowProperties);
		import kratos.input : mouse;
		mouse.setGrabbed(true);

		import kratos.resource.loader;
		auto scene = loadScene(Configuration.startupScene);

		import std.experimental.logger;
		globalLogLevel = LogLevel.info;
		Time.reset();
		while(!window.closeRequested)
		{
			window.updateInput();
			scene.rootDispatcher.frameUpdate();

			import kratos.component.renderer : Renderer;
			scene.components.firstOrAdd!Renderer().renderScene();

			window.swapBuffers();
			Time.update();
		}

		//activeFileSystem.write(Configuration.startupScene, scene.Scoped_payload.serializeToJson().toPrettyString);
	}
}