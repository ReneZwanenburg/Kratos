module kratos.main;

import kratos.time;
import kratos.window;

void main(string[] args)
{
	WindowProperties windowProperties = { };
	auto window = Window(windowProperties);
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
	import kratos.graphics.texture;

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
		shaderModule(ShaderModule.Type.Vertex,  "#version 330\nin vec3 position; uniform float scale; out vec2 texCoord; void main() { gl_Position = vec4(position * scale, 1); texCoord = position.xy; }"),
		shaderModule(ShaderModule.Type.Fragment,  "#version 330\nuniform sampler2D texture; uniform vec3 color; in vec2 texCoord; void main() { gl_FragData[0] = texture2D(texture, texCoord) * vec4(color, 1); }")
	));

	scope renderer = new MeshRenderer(quad, Shader(prog));
	renderer.shader["color"] = vec3(1, 1, 1);

	ubyte[] textureData = [
		255, 255, 255, 255,
		255,   0,   0, 255,
		  0, 255,   0, 255,
		  0,   0, 255, 255
	];

	renderer.shader["texture"] = texture(TextureFormat.RGBA, vec2i(2, 2), textureData);

	Time.reset();
	while(!window.closeRequested)
	{
		window.updateInput();

		import std.math;
		renderer.shader["scale"] = (sin(Time.total) + 1).to!float;


		import kratos.graphics.gl;
		gl.Clear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

		renderer.draw();

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