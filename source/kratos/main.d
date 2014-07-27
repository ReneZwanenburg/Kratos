module kratos.main;

import kratos.time;
import kratos.window;

void main(string[] args)
{
	auto window = Window(WindowProperties.init);
	//glfwSetKeyCallback(window, &glfwKeyCallback);

	import kratos.graphics.bo;
	import kratos.graphics.mesh;
	import kratos.graphics.shader;
	import gl3n.linalg;
	import kratos.graphics.shadervariable;
	import kratos.graphics.renderstate;
	import kratos.graphics.gl;
	import std.range;
	import kratos.component.meshrenderer;

	auto indices = ibo([
		0, 2, 1,
		1, 2, 3
	]);

	auto vertices = vbo([
		vec3(-.5f,	.5f,	0),
		vec3(.5f,	.5f,	0),
		vec3(-.5f,	-.5f,	0),
		vec3(.5f,	-.5f,	0)
	]);

	auto attributes = [ShaderParameter(1, GL_FLOAT_VEC3, "position")];

	auto quad = mesh(indices, vertices, attributes);

	auto prog = program(only(
		shaderModule(ShaderModule.Type.Vertex,  "in vec3 position; uniform float scale; void main() { gl_Position = vec4(position * scale, 1); }"),
		shaderModule(ShaderModule.Type.Fragment,  "uniform vec3 color; void main() { gl_FragData[0] = vec4(color, 1); }")
	));

	scope renderer = new MeshRenderer(quad, Shader(prog));
	renderer.shader["color"] = vec3(1, 0, 0);


	Time.reset();
	while(!window.closeRequested)
	{
		window.updateInput();

		import std.math;
		renderer.shader["scale"] = (sin(Time.total) + 1).to!float;

		renderer.draw();

		import kratos.graphics.gl;
		window.swapBuffers();
		gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
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