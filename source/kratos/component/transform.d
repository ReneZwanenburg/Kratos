module kratos.component.transform;

import kratos.entity;
import gl3n.linalg;


final class Transform : Component
{
	private Transform	_parent		= null;
	private vec3		_position	= vec3(0);
	private quat		_rotation	= quat.identity;
	//TODO: Decide if non-uniform scaling should be supported
	private float		_scale		= 1;

	private	mat4		_localMatrix	= mat4.identity;
	private	mat4		_worldMatrix	= mat4.identity;
	private	bool		_dirty			= false;

	@property
	{
		ref const(mat4) worldMatrix()
		{
			update();
			return _worldMatrix;
		}

		ref const(mat4) localMatrix()
		{
			update();
			return _localMatrix;
		}

		mat4 worldMatrixInv() const
		{
			auto mat = localMatrixInv;
			return _parent is null ? mat : mat * _parent.worldMatrixInv;
		}

		mat4 localMatrixInv() const
		{
			return buildMatrix(-_position, _rotation.inverse, 1 / _scale);
		}

		inout(Transform) parent() inout
		{
			return _parent;
		}

		void parent(Transform parent)
		{
			_parent = parent;
			mark();
		}

		vec3 position()	const
		{
			return _position;
		}

		void position(vec3 pos)
		{
			_position = pos;
			mark();
		}

		quat rotation() const
		{
			return _rotation;
		}

		void rotation(quat rotation)
		{
			_rotation = rotation;
			mark();
		}

		float scale() const
		{
			return _scale;
		}

		void scale(float scale)
		{
			_scale = scale;
			mark();
		}
	}

	private void update()
	{
		if(_dirty)
		{
			_localMatrix = buildMatrix(_position, _rotation, _scale);
			_worldMatrix = _parent is null ? _localMatrix : _localMatrix * _parent.worldMatrix;

			_dirty = false;
		}
	}

	private void mark()
	{
		_dirty = true;
	}

	private static mat4 buildMatrix(vec3 translation, quat rotation, float scale)
	{
		auto mat = rotation.to_matrix!(4,4) * mat4.scaling(scale, scale, scale);
		mat.matrix[0][3] = translation.x;
		mat.matrix[1][3] = translation.y;
		mat.matrix[2][3] = translation.z;
		return mat;
	}
}