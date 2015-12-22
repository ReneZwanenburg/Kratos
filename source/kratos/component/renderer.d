module kratos.component.renderer;

import kratos.ecs.scene : SceneComponent;
import kratos.ecs.component : dependency, ignore;

import kratos.component.meshrenderer : MeshRendererPartitioning;
import kratos.component.camera : Camera, CameraSelection;
import kratos.component.transform : Transform;
import kratos.component.light : DirectionalLightPartitioning, DirectionalLight, PointLightPartitioning, PointLight;

import kratos.graphics.rendertarget : RenderTarget, FrameBuffer;
import kratos.graphics.shadervariable : UniformRef;
import kratos.graphics.renderablemesh : RenderableMesh, renderableMesh;
import kratos.graphics.mesh : Mesh;
import kratos.graphics.bo : VBO, IBO;

import kgl3n.vector : vec2, vec2i, vec3, vec4;
import kgl3n.matrix : mat4;

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
		
		if(camera is null)
		{
			//TODO: Log warning
			return;
		}

		gBuffer.bind();
		gBuffer.clear();
		renderScene(camera);

		screen.bind();
		screen.clear();
		renderLights(camera);
	}

	private void renderScene(Camera camera)
	{
		auto v = camera.viewMatrix;
		auto p = camera.projectionMatrix;
		auto vp = camera.viewProjectionMatrix;

		foreach(meshRenderer; meshRenderers.all)
		{
			with(meshRenderer.mesh.renderState.shader.uniforms.builtinUniforms)
			{
				//TODO: Only assign bound uniforms
				auto w = meshRenderer.transform.worldMatrix;

				W = w;
				V = v;
				P = p;
				WV = v * w;
				VP = vp;
				WVP = vp * w;
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

	private void render(ref RenderableMesh renderableMesh)
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
			FrameBuffer.BufferDescription("normal", DefaultTextureFormat.RGBA16),
			FrameBuffer.BufferDescription("depth", DefaultTextureFormat.Depth)
		];

		return new FrameBuffer(size, bufferDescriptions);
	}
}

private struct DirectionalLightUniforms
{
	UniformRef!vec3 color;
	UniformRef!vec3 ambientColor;
	UniformRef!vec3 viewspaceDirection;
	UniformRef!mat4 projectionMatrixInverse;
}