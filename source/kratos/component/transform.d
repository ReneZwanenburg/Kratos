﻿module kratos.component.transform;

import kratos.entity;
import kgl3n.vector;
import kgl3n.quaternion;
import kgl3n.matrix;

mixin RegisterComponent!Transform;

final class Transform : Component
{
	@optional:
	private Transform	_parent = null;
	private vec3		_position;
	private quat		_rotation;
	//TODO: Decide if non-uniform scaling should be supported
	private float		_scale = 1;

	private	mat4		_localMatrix;
	private	mat4		_worldMatrix;
	private	bool		_dirty = false;

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

		void setLocalMatrix(mat4 matrix)
		{
			position = matrix.translation.xyz;
			rotation = quat.fromMatrix(mat3(matrix));
			scale = matrix.scale.x;
		}

		mat4 worldMatrixInv() const
		{
			auto mat = localMatrixInv;
			return _parent is null ? mat : mat * _parent.worldMatrixInv;
		}

		mat4 localMatrixInv() const
		{
			return mat4.scaling(vec3(1 / _scale)) * _rotation.inverted.toMatrix!(4) * mat4.translation(-_position);
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
			_localMatrix = mat4.translation(position) * rotation.toMatrix!(4) * mat4.scaling(vec3(scale));
			_worldMatrix = _parent is null ? _localMatrix : _localMatrix * _parent.worldMatrix;

			_dirty = false;
		}
	}

	private void mark()
	{
		_dirty = true;
	}
}