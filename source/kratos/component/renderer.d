module kratos.component.renderer;

import kratos.ecs.scene : SceneComponent;
import kratos.ecs.component : dependency, ignore;

import kratos.component.meshrenderer : MeshRendererPartitioning;
import kratos.component.camera : Camera;
import kratos.component.transform : Transform;

import kratos.graphics.rendertarget : RenderTarget, FrameBuffer;
import kratos.graphics.shadervariable : UniformRef, BuiltinUniformName;

import kgl3n.vector : vec2i;

//TODO: Make non-final, provide multiple renderer types? (forward, deferred)
final class Renderer : SceneComponent
{
	@ignore:

	@dependency
	private MeshRendererPartitioning meshRendererPartitioning;

	private RenderTarget gBuffer;
	private RenderTarget screen;

	this()
	{
		import kratos.window : currentWindow;
		screen = new RenderTarget(currentWindow.frameBuffer);
		gBuffer = new RenderTarget(createGBuffer(screen.frameBuffer.size));
	}

	void renderScene()
	{
		gBuffer.bind();
		gBuffer.clear();

		import std.algorithm.iteration : joiner, map;
		auto camera = scene.entities.map!(a => a.components.all!Camera).joiner.front;

		foreach(meshRenderer; meshRendererPartitioning.all)
		{
			//TODO: Maybe this needs some optimization
			foreach(builtinUniform; meshRenderer.renderState.shader.uniforms.builtinUniforms)
			{
				builtinUniformSetters[builtinUniform[0]](camera, meshRenderer.transform, builtinUniform[1]);
			}

			meshRenderer.renderState.apply();
			import kratos.graphics.gl;
			meshRenderer.vao.bind();
			gl.DrawElements(GL_TRIANGLES, meshRenderer.mesh.ibo.numIndices, meshRenderer.mesh.ibo.indexType, null);
		}
	}

	private static FrameBuffer createGBuffer(vec2i size)
	{
		import kratos.graphics.texture : DefaultTextureFormat;

		static bufferDescriptions = [
			FrameBuffer.BufferDescription("albedo", DefaultTextureFormat.RGBA),
			FrameBuffer.BufferDescription("normal", DefaultTextureFormat.RGBA),
			FrameBuffer.BufferDescription("depth", DefaultTextureFormat.Depth)
		];

		return new FrameBuffer(size, bufferDescriptions);
	}
}

private alias BuiltinUniformSetter = void function(Camera, Transform, UniformRef);
private static immutable BuiltinUniformSetter[string] builtinUniformSetters;
static this()
{
	foreach(name; BuiltinUniformName)
	{
		switch(name)
		{
			case "W":	builtinUniformSetters[name] = (camera, transform, uniform)
				{ uniform = transform.worldMatrix; }; 								break;
			case "V":	builtinUniformSetters[name] = (camera, transform, uniform)
				{ uniform = camera.viewMatrix; };									break;
			case "P":	builtinUniformSetters[name] = (camera, transform, uniform)
				{ uniform = camera.projectionMatrix; };								break;
			case "WV":	builtinUniformSetters[name] = (camera, transform, uniform)
				{ uniform = camera.viewMatrix * transform.worldMatrix; };			break;
			case "VP":	builtinUniformSetters[name] = (camera, transform, uniform)
				{ uniform = camera.viewProjectionMatrix; };							break;
			case "WVP":	builtinUniformSetters[name] = (camera, transform, uniform)
				{ uniform = camera.viewProjectionMatrix * transform.worldMatrix; };	break;
				
			default:	assert(false, "No setter implemented for Uniform " ~ name);
		}
	}
}