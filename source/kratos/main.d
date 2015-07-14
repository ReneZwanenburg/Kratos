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
		import vibe.data.json;
		import std.typecons : scoped;
		auto scene = loadScene(Configuration.startupScene);

		import std.experimental.logger;
		globalLogLevel = LogLevel.info;
		Time.reset();
		while(!window.closeRequested)
		{
			window.updateInput();
			//import kratos.ecs : dispatchFrameUpdate;
			//dispatchFrameUpdate();

			import kratos.component.camera;
			import std.algorithm.iteration : map, joiner;
			foreach(camera; scene.entities.map!(a => a.components.all!Camera).joiner)
			{
				camera.render();
			}

			window.swapBuffers();
			Time.update();
		}

		//activeFileSystem.write(Configuration.startupScene, scene.Scoped_payload.serializeToJson().toPrettyString);
	}
}