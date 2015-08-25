module kratos.component.renderer;

import kratos.ecs.scene : SceneComponent;
import kratos.ecs.component : dependency, ignore;

import kratos.component.meshrenderer : MeshRendererPartitioning;
import kratos.component.camera : Camera, CameraSelection;
import kratos.component.transform : Transform;
import kratos.component.light : DirectionalLightPartitioning, DirectionalLight, PointLightPartitioning, PointLight;

import kratos.graphics.rendertarget : RenderTarget, FrameBuffer;
import kratos.graphics.shadervariable : UniformRef, BuiltinUniformName;
import kratos.graphics.renderablemesh : RenderableMesh, renderableMesh;
import kratos.graphics.mesh : Mesh;
import kratos.graphics.bo : VBO, IBO;

import kgl3n.vector : vec2, vec2i, vec4;

//TODO: Make non-final, provide multiple renderer types? (forward, deferred)
final class Renderer : SceneComponent
{
	@ignore:

	private @dependency
	{
		CameraSelection cameraSelection;
		MeshRendererPartitioning meshRenderers;
		DirectionalLightPartitioning directionalLights;
		PointLightPartitioning pointLights;
	}

	private RenderTarget gBuffer;
	private RenderTarget screen;

	private RenderableMesh directionalLightRenderableMesh = void;
	private RenderableMesh pointLightRenderableMesh = void;

	private DirectionalLightUniforms directionalLightUniforms;

	this()
	{
		import kratos.window : currentWindow;
		screen = new RenderTarget(currentWindow.frameBuffer);
		gBuffer = new RenderTarget(createGBuffer(screen.frameBuffer.size));

		initRenderMeshes();
		initUniformRefs();
	}

	void renderScene()
	{
		auto camera = cameraSelection.mainCamera;

		gBuffer.bind();
		gBuffer.clear();
		renderScene(camera);

		screen.bind();
		screen.clear();
		renderLights(camera);
	}

	private void renderScene(Camera camera)
	{
		foreach(meshRenderer; meshRenderers.all)
		{
			//TODO: Maybe this needs some optimization
			foreach(builtinUniform; meshRenderer.mesh.renderState.shader.uniforms.builtinUniforms)
			{
				builtinUniformSetters[builtinUniform[0]](camera, meshRenderer.transform, builtinUniform[1]);
			}
			
			render(meshRenderer.mesh);
		}
	}

	private void renderLights(Camera camera)
	{
		directionalLightUniforms.projectionMatrixInverse = camera.projectionMatrix.inverse;

		foreach(light; directionalLights.all)
		{
			with(directionalLightUniforms)
			{
				color = light.color;
				ambientColor = light.ambientColor;
				viewspaceDirection = (camera.viewMatrix * vec4(light.direction.normalized, 0)).xyz;
			}

			render(directionalLightRenderableMesh);
		}
	}

	private void render(RenderableMesh renderableMesh)
	{
		with(renderableMesh)
		{
			renderState.apply();
			vao.bind();
			import kratos.graphics.gl;
			gl.DrawElements(GL_TRIANGLES, mesh.ibo.numIndices, mesh.ibo.indexType, null);
		}
	}

	private void initRenderMeshes()
	{
		auto quad = createFullscreenQuad();

		import kratos.resource.loader.renderstateloader;

		void setGBufferInputs(ref RenderableMesh mesh)
		{
			directionalLightRenderableMesh.renderState.shader["albedo"] = gBuffer.frameBuffer["albedo"];
			directionalLightRenderableMesh.renderState.shader["normal"] = gBuffer.frameBuffer["normal"];
			directionalLightRenderableMesh.renderState.shader["depth"] = gBuffer.frameBuffer["depth"];
		}

		this.directionalLightRenderableMesh = renderableMesh(quad, RenderStateCache.get("RenderStates/DeferredRenderer/DirectionalLight.renderstate"));
		setGBufferInputs(this.directionalLightRenderableMesh);
	}

	private void initUniformRefs()
	{
		directionalLightUniforms = directionalLightRenderableMesh.renderState.shader.getRefs!DirectionalLightUniforms;
	}

	private Mesh createFullscreenQuad()
	{
		static struct Vertex
		{
			vec2 position;
		}

		auto vbo = VBO([
				Vertex(vec2(-1, 1)),
				Vertex(vec2(1, 1)),
				Vertex(vec2(-1, -1)),
				Vertex(vec2(1, -1))
			]);
		auto ibo = IBO([0u, 2u, 1u, 1u, 2u, 3u]);
		
		return Mesh(ibo, vbo);
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

private struct DirectionalLightUniforms
{
	UniformRef color;
	UniformRef ambientColor;
	UniformRef viewspaceDirection;
	UniformRef projectionMatrixInverse;
}