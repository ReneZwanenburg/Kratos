module kratos.configuration;

import kratos.resource.filesystem;
import vibe.data.json;

import kratos.window : WindowProperties;

public immutable ConfigurationImpl Configuration;

private struct ConfigurationImpl
{
	@optional:
	string startupScene;
	WindowProperties defaultWindowProperties;
	InputSettings inputSettings;
}

shared static this()
{
	auto jsonString = activeFileSystem.get("Kratos").asText;
	Configuration = jsonString.parseJson().deserializeJson!ConfigurationImpl;
}

private struct InputSettings
{
	@optional:
	bool grabMouse = false;
}