﻿module kratos.component.camera;

import kratos.ecs.component : dependency;
import kratos.ecs.entity : Component;
import kratos.ecs.scene : SceneComponent;

import kratos.component.transform;
import kgl3n.matrix;
import kgl3n.linearcomponent;
import kgl3n.vector;
import vibe.data.json;
import std.conv : to;

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
	private @dependency Transform _transform;
	private @dependency CameraSelection cameraSelection;

	private mat4				_projectionMatrix;
	private StandardProjection	standardProjection;
	private bool				customProjection = false;

	this()
	{
		projectionMatrix = StandardProjection();
	}

	@property
	{
		mat4 viewProjectionMatrix() const
		{
			return projectionMatrix * _transform.worldMatrixInv;
		}
		
		mat4 viewMatrix() const
		{
			return _transform.worldMatrixInv;
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
				(Window.activeProperties.width / to!float(Window.activeProperties.height)) : 
				projection.aspectRatio;

			_projectionMatrix = perspectiveProjection(aspect, 1, projection.fov, projection.nearPlane, projection.farPlane);
			customProjection = false;
		}

		bool mainCamera()
		{
			return cameraSelection.mainCamera is this;
		}

		inout(Transform) transform() inout
		{
			return _transform;
		}
	}

	Ray createPickRay(vec2 clipCoords)
	{
		auto invProjection = projectionMatrix.inverse;
		auto unprojectedDirection = (invProjection * vec4(clipCoords, -1, 1)).xy;
		return Ray(transform.worldTransformation.position, (transform.worldMatrix * vec4(unprojectedDirection, -1, 0)).xyz.normalized);
	}

	public void makeMainCamera()
	{
		cameraSelection.mainCamera = this;
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

		if(json["customProjection"].to!bool)
		{
			camera.projectionMatrix = json["projection"].deserializeJson!mat4;
		}
		else
		{
			auto projection = json["projection"];
			camera.projectionMatrix = projection.type == Json.Type.undefined
				? StandardProjection.init
				: projection.deserializeJson!StandardProjection;
		}

		auto mainJson = json["main"];
		// Dependencies have not been set at this point, but scene is set during construction so use that.
		auto cameraSelection = camera.scene.components.firstOrAdd!CameraSelection;

		if(mainJson.type == Json.Type.undefined)
		{
			if(cameraSelection.mainCamera is null)
			{
				cameraSelection.mainCamera = camera;
			}
		}
		else if(mainJson.get!bool)
		{
			cameraSelection.mainCamera = camera;
		}

		return camera;
	}
}

public final class CameraSelection : SceneComponent
{
	private Camera _mainCamera;

	@property
	{
		Camera mainCamera()
		{
			return _mainCamera;
		}

		void mainCamera(Camera newMainCamera)
		{
			_mainCamera = newMainCamera;
		}
	}
}