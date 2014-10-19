module kratos.component.camera;

import kratos.entity;
import kratos.component.transform;
import kgl3n.matrix;
import vibe.data.json;

mixin RegisterComponent!Camera;

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
	private @dependency Transform transform;

	private mat4				_projectionMatrix;
	private StandardProjection	standardProjection;
	private bool				customProjection = false;

	this()
	{
		projectionMatrix = StandardProjection();

		if(current is null)
		{
			makeCurrent();
		}
	}

	~this()
	{
		if(_current is this)
		{
			_current = null;
		}
	}

	public void makeCurrent()
	{
		_current = this;
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

	static {
		private Camera _current;

		public @property Camera current()
		{
			return _current;
		}
	}
}