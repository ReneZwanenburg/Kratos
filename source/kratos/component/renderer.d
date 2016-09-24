module kratos.component.renderer;

import kratos.ecs.scene : SceneComponent;
import kratos.ecs.component : dependency, ignore;

import kratos.component.meshrenderer : MeshRenderer, MeshRendererPartitioning;
import kratos.component.camera : Camera, CameraSelection;
import kratos.component.transform : Transform;
import kratos.component.light : DirectionalLightPartitioning, DirectionalLight, PointLightPartitioning, PointLight;

import kratos.ui.panel;

import kratos.graphics.rendertarget : RenderTarget, FrameBuffer;
import kratos.graphics.renderstate : RenderState;
import kratos.graphics.shadervariable : UniformRef;
import kratos.graphics.renderablemesh : RenderableMesh, renderableMesh;
import kratos.graphics.mesh : Mesh, MeshManager, quad2D;
import kratos.graphics.bo : VBO, IBO;

import kgl3n.vector : vec2, vec2ui, vec3, vec4;
import kgl3n.matrix : mat4;
import kgl3n.frustum : Frustum;
import kgl3n.math : max;

import std.experimental.logger;

final class Renderer : SceneComponent
{
	@ignore:

	private @dependency
	{
		CameraSelection cameraSelection;
		MeshRendererPartitioning meshRenderers;
		DirectionalLightPartitioning directionalLights;
		PointLightPartitioning pointLights;
		UiComponentPartitioning uiComponents;
	}

	private
	{
		RenderTarget gBuffer;
		RenderTarget screen;

		RenderableMesh directionalLightRenderableMesh = void;
		RenderableMesh pointLightRenderableMesh = void;

		DirectionalLightUniforms directionalLightUniforms;
		
		RenderQueues renderQueues;
	}
	
	@property
	{
		vec2ui gBufferResolution() const
		{
			return gBuffer.frameBuffer.size;
		}
		
		vec2ui screenResolution() const
		{
			return screen.frameBuffer.size;
		}
	}

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
			warning("Main camera not set, unable to render Scene");
			return;
		}

		gBuffer.bind();
		gBuffer.clear();
		renderScene(camera);

		screen.bind();
		screen.clear();
		renderLights(camera);
		
		renderUi();
	}

	private void renderScene(Camera camera)
	{
		auto v = camera.viewMatrix;
		auto p = camera.projectionMatrix;
		auto vp = camera.viewProjectionMatrix;
		auto worldSpaceFrustum = Frustum(vp);
		
		renderQueues.clear();
		foreach(meshRenderer; meshRenderers.intersecting(worldSpaceFrustum))
		{
			renderQueues.enqueue(meshRenderer);
		}
		//TODO: Sort transparent queue
		
		foreach(queue; renderQueues.queues)
		{
			//TODO: Transparent queue should use forward rendering
			foreach(meshRenderer; queue[])
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
	
	private void renderUi()
	{
		foreach(uiComponent; uiComponents.all)
		{
			with(uiComponent.mesh.renderState.shader.uniforms.builtinUniforms)
			{
				W = uiComponent.transform.worldMatrix;
			}
			
			render(uiComponent.mesh);
		}
	}

	private void render(ref RenderableMesh renderableMesh)
	{
		with(renderableMesh)
		{
			renderState.apply();
			vao.bind();
			auto meshImpl = MeshManager.getConcreteResource(mesh);
			import kratos.graphics.gl;
			gl.DrawElements(GL_TRIANGLES, meshImpl.ibo.numIndices, meshImpl.ibo.indexType, null);
		}
	}

	private void initRenderMeshes()
	{
		auto quad = quad2D(vec2(-1, -1), vec2(1, 1));

		import kratos.resource.loader.renderstateloader;

		void setGBufferInputs(ref RenderableMesh mesh)
		{
			directionalLightRenderableMesh.renderState.shader["albedo"] = gBuffer.frameBuffer["albedo"];
			directionalLightRenderableMesh.renderState.shader["normal"] = gBuffer.frameBuffer["normal"];
			directionalLightRenderableMesh.renderState.shader["depth"] = gBuffer.frameBuffer["depth"];
		}

		this.directionalLightRenderableMesh = renderableMesh(quad, RenderStateLoader.get("RenderStates/DeferredRenderer/DirectionalLight"));
		setGBufferInputs(this.directionalLightRenderableMesh);
	}

	private void initUniformRefs()
	{
		directionalLightUniforms = directionalLightRenderableMesh.renderState.shader.getRefs!DirectionalLightUniforms;
	}

	private static FrameBuffer createGBuffer(vec2ui size)
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

private struct RenderQueues
{
	RenderQueue[RenderState.Queue.max + 1] queues;
	
	void clear()
	{
		foreach(ref queue; queues) queue.clear();
	}
	
	void enqueue(MeshRenderer meshRenderer)
	{
		queues[meshRenderer.mesh.renderState.queue] ~= meshRenderer;
	}
}

private struct RenderQueue
{
	private
	{
		MeshRenderer[] backingArray;
		size_t used;
	}
	
	void clear()
	{
		used = 0;
		//TODO: Clear backingArray?
	}
	
	void opOpAssign(string op : "~")(MeshRenderer meshRenderer) 
	{
		if(used == backingArray.length)
		{
			backingArray.length = max(16, backingArray.length * 2);
		}
		
		backingArray[used++] = meshRenderer;
	}
	
	MeshRenderer[] opIndex()
	{
		return backingArray[0 .. used];
	}
}

private struct DirectionalLightUniforms
{
	UniformRef!vec3 color;
	UniformRef!vec3 ambientColor;
	UniformRef!vec3 viewspaceDirection;
	UniformRef!mat4 projectionMatrixInverse;
}