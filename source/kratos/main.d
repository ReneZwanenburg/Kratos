module kratos.main;

import kratos.time;
import kratos.window;

void main(string[] args)
{
	auto window = Window(WindowProperties.init);
	//glfwSetKeyCallback(window, &glfwKeyCallback);

	Time.reset();
	while(!window.closeRequested)
	{
		window.updateInput();

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