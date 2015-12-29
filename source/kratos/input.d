module kratos.input;

import kratos.window;
import derelict.glfw3.glfw3;

struct Axis
{
	string name;

	float value = 0;
	float delta = 0;

	private void update(float newValue)
	{
		delta = newValue - value;
		value = newValue;
	}
}

struct Button
{
	string name;
	bool pressed;
	bool changed;

	@property const
	{
		bool released()
		{
			return !pressed;
		}

		bool justPressed()
		{
			return pressed && changed;
		}

		bool justReleased()
		{
			return released && changed;
		}
	}

	private void update(bool newPressed)
	{
		changed = newPressed != pressed;
		pressed = newPressed;
	}
}

struct Pointer
{
	import kgl3n.vector : vec2;

	string	name;
	vec2	position;
}

private Mouse _mouse;

public @property Mouse mouse()
{
	return _mouse;
}

package @property void mouse(Mouse mouse)
{
	_mouse = mouse;
}

class Mouse
{
	private Button[GLFW_MOUSE_BUTTON_LAST] _buttons;
	private Axis _xAxis, _yAxis;
	private Pointer _absolutePointer;

	private GLFWwindow* windowHandle;

	package this(ref Window window)
	{
		this.windowHandle = window.handle;

		foreach(i, ref button; _buttons)
		{
			import std.conv : text;
			button = Button("Mouse Button " ~ i.text);
		}

		_xAxis = Axis("Mouse X axis", 0, window.properties.width);
		_yAxis = Axis("Mouse Y axis", 0, window.properties.height);

		_absolutePointer = Pointer("Mouse Pointer");
	}

	package void update()
	{
		//TODO: Support delta-only mode
		{
			import kgl3n.vector : vec2;

			double tmpX, tmpY;
			glfwGetCursorPos(windowHandle, &tmpX, &tmpY);
			vec2 currentPointer = vec2(tmpX, tmpY);
			auto pointerDelta = currentPointer - _absolutePointer.position;

			_xAxis.update(pointerDelta.x);
			_yAxis.update(pointerDelta.y);
			_absolutePointer.position = currentPointer;
		}

		foreach(uint i, ref button; _buttons)
		{
			button.update(glfwGetMouseButton(windowHandle, i) == GLFW_PRESS);
		}
	}
	
	@property
	{
		void grabbed(bool grab)
		{
			glfwSetInputMode(windowHandle, GLFW_CURSOR, grab ? GLFW_CURSOR_DISABLED : GLFW_CURSOR_NORMAL);
		}
		
		bool grabbed()
		{
			return glfwGetInputMode(windowHandle, GLFW_CURSOR) == GLFW_CURSOR_DISABLED;
		}
	}

	@property const
	{
		auto xAxis()
		{
			return _xAxis;
		}

		auto yAxis()
		{
			return _yAxis;
		}

		auto buttons()
		{
			return _buttons[];
		}

		auto absolutePointer()
		{
			return _absolutePointer;
		}
	}
}


private Keyboard _keyboard;

public @property Keyboard keyboard()
{
	return _keyboard;
}

package @property void keyboard(Keyboard keyboard)
{
	_keyboard = keyboard;
}

class Keyboard
{
	private ButtonMapping[] _buttons;
	private size_t[string] _mapping;

	private GLFWwindow* _windowHandle;

	package this(ref Window window)
	{
		this._windowHandle = window.handle;

		foreach(member; __traits(allMembers, derelict.glfw3.glfw3))
		{
			import std.algorithm : startsWith, splitter, joiner, map;
			import std.conv;
			import std.string : capitalize;

			enum keyPrefix = "GLFW_KEY_";
			static if(member.startsWith(keyPrefix) && member != "GLFW_KEY_UNKNOWN")
			{
				auto keyName = member[keyPrefix.length .. $].splitter('_').map!capitalize.joiner(" ").to!string;
				_mapping[keyName] = buttons.length;
				_buttons ~= ButtonMapping(Button(keyName), mixin(member));
			}
		}
	}

	package void update()
	{
		foreach(ref b; _buttons)
		{
			b.button.update(glfwGetKey(_windowHandle, b.keyCode) == GLFW_PRESS);
		}
	}

	ref const(Button) opIndex(string keyName) const
	{
		return _buttons[_mapping[keyName]].button;
	}

	private static struct ButtonMapping
	{
		private Button button;
		private int keyCode;
	}

	public auto buttons()
	{
		import std.algorithm : map;
		return _buttons.map!(a => a.button);
	}
}
