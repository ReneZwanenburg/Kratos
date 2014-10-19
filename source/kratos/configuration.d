﻿module kratos.configuration;

import kratos.resource.filesystem;
import vibe.data.json;

import kratos.window : WindowProperties;

public immutable ConfigurationImpl Configuration;

private struct ConfigurationImpl
{
	@optional:
	string startupScene;
	WindowProperties defaultWindowProperties;
}

shared static this()
{
	auto jsonString = activeFileSystem.getText("Kratos.json");
	Configuration = jsonString.parseJson().deserializeJson!ConfigurationImpl;
}