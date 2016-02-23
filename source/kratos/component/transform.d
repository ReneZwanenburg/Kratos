module kratos.component.transform;

import kratos.ecs;
import kgl3n.vector;
import kgl3n.quaternion;
import kgl3n.matrix;
import kratos.util : Event;

final class Transform : Component
{
	@ignore Transformation	localTransformation;

	private Transform		_parent;
	private	mat4			_localMatrix;
	private	mat4			_worldMatrix;
	private Transformation	_previousUpdateFransformation;
	private bool			_refreshParentTransformation;
	
	//TODO: World rotation, scale
	private vec3 			_worldPosition;

	public Event!Transform onLocalTransformChanged;
	public Event!Transform onWorldTransformChanged;

	alias ChangedRegistration = onLocalTransformChanged.RegistrationType;
	
	private ChangedRegistration parentWorldTransformChangedRegistration;

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
		
		vec3 worldPosition() const
		{
			return _worldPosition;
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
		
		inout(Transform) parent() inout
		{
			return _parent;
		}
		
		bool isRoot() const
		{
			return parent is null;
		}
		
		void parent(Transform parent)
		{
			//TODO: update dispatcher chain, invalidate depth
			_parent = parent;
			
			if(parent is null)
			{
				parentWorldTransformChangedRegistration = ChangedRegistration.init;
				_worldMatrix = _localMatrix;
			}
			else
			{
				parentWorldTransformChangedRegistration = parent.onWorldTransformChanged.register(&invalidateParentTransform);
				invalidateParentTransform(parent);
			}
		}
	}
	
	private void invalidateParentTransform(Transform parent)
	{
		assert(parent is this.parent);
		_refreshParentTransformation = true;
	}

	void frameUpdate()
	{
		//TODO: Ensure correct update order of hierarchies
		
		auto updateLocal = _previousUpdateFransformation !is localTransformation;
		auto updateWorld = _refreshParentTransformation || updateLocal;
		auto worldUpdated = false;
		
		if(updateLocal)
		{
			_localMatrix = localTransformation.toMatrix();
			_previousUpdateFransformation = localTransformation;
		}
		if(updateWorld)
		{
			mat4 newWorldMatrix = parent is null ? _localMatrix : parent.worldMatrix * _localMatrix;
			worldUpdated = newWorldMatrix !is _worldMatrix;
			_worldMatrix = newWorldMatrix;
			
			if(worldUpdated)
			{
				_worldPosition = _worldMatrix.col(3).xyz;
			}
		}

		onLocalTransformChanged.raiseIf(updateLocal, this);
		onWorldTransformChanged.raiseIf(worldUpdated, this);
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