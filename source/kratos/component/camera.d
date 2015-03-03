module kratos.component.camera;

import kratos.ecs;
import kratos.component.transform;
import kratos.component.meshrenderer;
import kratos.graphics.rendertarget;
import kgl3n.matrix;
import vibe.data.json;

struct StandardProjection
{
	@optional:
	float aspectRatio = 0;
	float fov = 60;
	float nearPlane = .1f;
	float farPlane = 2000;
}

final class Camera : Component
{
	mixin RegisterComponent;

	private @dependency Transform transform;

	private mat4				_projectionMatrix;
	private StandardProjection	standardProjection;
	private RenderTarget		renderTarget;
	private bool				customProjection = false;

	this()
	{
		renderTarget = new RenderTarget();
		projectionMatrix = StandardProjection();
	}

	// Should be package(kratos)
	public void render()
	{
		renderTarget.apply();
		renderTarget.clear();

		foreach(meshRenderer; scene.getComponents!MeshRenderer)
		{
			//TODO: Maybe this needs some optimization
			foreach(builtinUniform; meshRenderer.renderState.shader.uniforms.builtinUniforms)
			{
				builtinUniformSetters[builtinUniform[0]](this, meshRenderer.transform, builtinUniform[1]);
			}

			meshRenderer.renderState.apply();
			import kratos.graphics.gl;
			meshRenderer.vao.bind();
			gl.DrawElements(GL_TRIANGLES, meshRenderer.mesh.ibo.numIndices, meshRenderer.mesh.ibo.indexType, null);
		}
	}

	@property
	{
		mat4 viewProjectionMatrix() const
		{
			return projectionMatrix * transform.worldMatrixInv;
		}
		
		mat4 viewMatrix() const
		{
			return transform.worldMatrixInv;
		}

		mat4 projectionMatrix() const
		{
			return _projectionMatrix;
		}

		void projectionMatrix(mat4 matrix)
		{
			_projectionMatrix = matrix;
			customProjection = true;
		}

		void projectionMatrix(StandardProjection projection)
		{
			this.standardProjection = projection;

			import kratos.window;
			auto aspect = projection.aspectRatio <= 0 ? 
				(Window.activeProperties.width / cast(float)Window.activeProperties.height) : 
				projection.aspectRatio;

			_projectionMatrix = perspectiveProjection(aspect, 1, projection.fov, projection.nearPlane, projection.farPlane);
			customProjection = false;
		}
	}


	Json toRepresentation()
	{
		auto json = Json.emptyObject;
		json["customProjection"] = customProjection;
		if(customProjection)
		{
			json["projection"] = _projectionMatrix.serializeToJson;
		}
		else
		{
			json["projection"] = standardProjection.serializeToJson;
		}

		return json;
	}

	static Camera fromRepresentation(Json json)
	{
		auto camera = new Camera();

		if(json["customProjection"].get!bool)
		{
			camera.projectionMatrix = json["projection"].deserializeJson!mat4;
		}
		else
		{
			camera.projectionMatrix = json["projection"].deserializeJson!StandardProjection;
		}

		return camera;
	}
	
	private alias BuiltinUniformSetter = void function(Camera, Transform, UniformRef);
	private static immutable BuiltinUniformSetter[string] builtinUniformSetters;
	static this()
	{
		import kratos.component.camera : Camera;
		
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
}