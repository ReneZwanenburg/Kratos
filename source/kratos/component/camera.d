module kratos.component.camera;

import kratos.entity;
import kratos.component.transform;

import kgl3n.matrix;

final class Camera : Component
{
	private @dependency Transform transform;

	public mat4 projectionMatrix;

	this()
	{
		import kratos.window;
		projectionMatrix = perspectiveProjection(Window.activeProperties.width, Window.activeProperties.height, 80, .1f, 1000);
	}

	~this()
	{
		if(_current == this)
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