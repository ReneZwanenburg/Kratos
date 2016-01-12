module kratos.component.transform;

import kratos.ecs;
import kgl3n.vector;
import kgl3n.quaternion;
import kgl3n.matrix;
import kratos.util : Event;

final class Transform : Component
{
	@ignore Transform		parent = null;
	@ignore Transformation	localTransformation;

	private	mat4			_localMatrix;
	private	mat4			_worldMatrix;

	public Event!Transform onLocalTransformChanged;
	public Event!Transform onWorldTransformChanged;

	alias ChangedRegistration = onLocalTransformChanged.RegistrationType;

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

		ref scale() const
		{
			return localTransformation.scale;
		}

		ref const(mat4) worldMatrix() const
		{
			return _worldMatrix;
		}

		ref const(mat4) localMatrix() const
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
		//TODO: Use some form of update-if-dirty
		mat4 newLocalMatrix = localTransformation.toMatrix();
		mat4 newWorldMatrix = parent is null ? newLocalMatrix : newLocalMatrix * parent.worldMatrix;

		bool localMatrixChanged = newLocalMatrix !is localMatrix;
		bool worldMatrixChanged = newWorldMatrix !is worldMatrix;

		_localMatrix = newLocalMatrix;
		_worldMatrix = newWorldMatrix;

		onLocalTransformChanged.raiseIf(localMatrixChanged, this);
		onWorldTransformChanged.raiseIf(worldMatrixChanged, this);
	}
}

struct Transformation
{
	vec3 position;
	float scale = 1;
	quat rotation;

	mat4 toMatrix() const
	{
		auto retVal = rotation.toMatrix!4;
		retVal *= scale;
		retVal[0].w = position.x;
		retVal[1].w = position.y;
		retVal[2].w = position.z;
		retVal[3].w = 1;
		
		return retVal;
	}

	mat4 toMatrixInverse() const
	{
		auto invRotation = rotation.inverted;
		auto invPosition = invRotation * -position;
		auto retVal = invRotation.toMatrix!4;
		retVal *= (1 / scale);
		retVal[0].w = invPosition.x;
		retVal[1].w = invPosition.y;
		retVal[2].w = invPosition.z;
		retVal[3].w = 1;
		
		return retVal;
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