module kratos.component.transform;

import kratos.ecs;
import kgl3n.vector;
import kgl3n.quaternion;
import kgl3n.matrix;

final class Transform : Component
{
	@ignore Transform		parent = null;
	@ignore Transformation	localTransformation;

	private	mat4			_localMatrix;
	private	mat4			_worldMatrix;

	@property
	{
		@optional:

		ref position()
		{
			return localTransformation.position;
		}

		ref rotation()
		{
			return localTransformation.rotation;
		}

		ref scale()
		{
			return localTransformation.scale;
		}

		ref const(mat4) worldMatrix()
		{
			return _worldMatrix;
		}

		ref const(mat4) localMatrix()
		{
			return _localMatrix;
		}

		mat4 worldMatrixInv() const
		{
			auto mat = localMatrixInv;
			return parent is null ? mat : mat * parent.worldMatrixInv;
		}

		mat4 localMatrixInv() const
		{
			return localTransformation.toMatrixInverse;
		}

		string path() const
		{
			auto path = owner.name;
			return parent !is null ? parent.path ~ "/" ~ path : path;
		}
	}

	void frameUpdate()
	{
		//TODO: Ensure correct update order of hierarchies
		_localMatrix = localTransformation.toMatrix();
		_worldMatrix = parent is null ? _localMatrix : _localMatrix * parent.worldMatrix;
	}
}

struct Transformation
{
	vec3 position;
	float scale = 1;
	quat rotation;

	mat4 toMatrix() const
	{
		//TODO: Compose in a sane way. This is _extremely_ inefficient
		return mat4.translation(position) * rotation.toMatrix!(4) * mat4.scaling(vec3(scale));
	}

	mat4 toMatrixInverse() const
	{
		return mat4.scaling(vec3(1 / scale)) * rotation.inverted.toMatrix!(4) * mat4.translation(-position);
	}

	static Transformation fromMatrix(ref mat4 matrix)
	{
		return Transformation
		(
			matrix.translation.xyz,
			matrix.scale.x,
			quat.fromMatrix(mat3(matrix))
		);
	}

	static Transformation interpolate(ref Transformation from, ref Transformation to, float phase)
	{
		import kgl3n.interpolate : lerp, slerp;

		return Transformation
		(
			lerp(from.position, to.position, phase),
			lerp(from.scale, to.scale, phase),
			slerp(from.rotation, to.rotation, phase)
		);
	}
}