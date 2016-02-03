module kratos.configuration;

import kratos.resource.filesystem;
import kvibe.data.json;

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
	auto jsonString = activeFileSystem.getText("Kratos.json");
	Configuration = jsonString.parseJson().deserializeJson!ConfigurationImpl;
}

private struct InputSettings
{
	@optional:
	bool grabMouse = false;
}