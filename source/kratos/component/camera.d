module kratos.component.camera;

import kratos.entity;
import kratos.component.transform;

import kgl3n.matrix;

private alias registration = RegisterComponent!Camera;

final class Camera : Component
{
	@optional:
	private @dependency Transform transform;

	public mat4 projectionMatrix;

	this()
	{
		import kratos.window;
		projectionMatrix = perspectiveProjection(Window.activeProperties.width, Window.activeProperties.height, 60, .1f, 2000);

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

	public @property mat4 viewProjectionMatrix() const
	{
		return projectionMatrix * transform.worldMatrixInv;
	}

	public @property mat4 viewMatrix() const
	{
		return transform.worldMatrixInv;
	}

	static{
		private Camera _current;

		public @property Camera current()
		{
			return _current;
		}
	}
}