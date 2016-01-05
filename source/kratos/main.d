module kratos.main;

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
		mouse.grabbed = Configuration.inputSettings.grabMouse;

		import kratos.resource.loader;
		auto scene = loadScene(Configuration.startupScene);

		//import std.experimental.logger;
		//globalLogLevel = LogLevel.info;
		while(!window.closeRequested)
		{
			window.updateInput();
			scene.rootDispatcher.frameUpdate();

			import kratos.component.renderer : Renderer;
			scene.components.firstOrAdd!Renderer().renderScene();

			window.swapBuffers();
			import kratos.component.time : Time;
			scene.components.firstOrAdd!Time().update();
		}

		//activeFileSystem.write(Configuration.startupScene, scene.serialize().toPrettyString);
	}
}