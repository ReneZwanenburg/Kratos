module kratos.component.physics;

import kratos.ecs.scene : SceneComponent;
import kratos.ecs.entity : Component;
import kratos.ecs.component : Dependency, dependency, byName, optional, ignore;
import kratos.component.time : Time;
import kratos.component.transform : Transform, Transformation;
import kgl3n.vector : vec2, vec3, vec4;
import kgl3n.quaternion : quat;
import derelict.ode.ode;

public final class RigidBody : Component
{
	private PhysicsWorld world;
	private dBodyID bodyId;
	
	private @dependency(Dependency.Direction.Write) Transform transform;
	
	private Transformation previousStepTransformation;
	private Transformation currentStepTransformation;
	
	//The ODE docs aren't quite clear how long I can keep these around..
	private float[] positionStore;
	private float[] rotationStore;
	
	this()
	{
		world = scene.components.firstOrAdd!PhysicsWorld;
		bodyId = world.createBody();
		dBodySetData(bodyId, cast(void*)this);
		dBodySetMovedCallback(bodyId, &bodyMovedCallback);

		positionStore = dBodyGetPosition(bodyId)[0 .. 3];
		rotationStore = dBodyGetRotation(bodyId)[0 .. 4];
	}
	
	~this()
	{
		//TODO: Destroy attached joints
		dBodyDestroy(bodyId);
	}

	public void addForce(vec3 force)
	{
		dBodyAddForce(bodyId, force.x, force.y, force.z);
	}
	
	public void addRelativeForce(vec3 force)
	{
		dBodyAddRelForce(bodyId, force.x, force.y, force.z);
	}
	
	public void addForceAtWorldPosition(vec3 force, vec3 pos)
	{
		dBodyAddForceAtPos(bodyId, force.x, force.y, force.z, pos.x, pos.y, pos.z);
	}
	
	public void addForceAtLocalPosition(vec3 force, vec3 pos)
	{
		dBodyAddForceAtRelPos(bodyId, force.x, force.y, force.z, pos.x, pos.y, pos.z);
	}
	
	public void addRelativeForceAtWorldPosition(vec3 force, vec3 pos)
	{
		dBodyAddRelForceAtPos(bodyId, force.x, force.y, force.z, pos.x, pos.y, pos.z);
	}
	
	public void addRelativeForceAtRelativePosition(vec3 force, vec3 pos)
	{
		dBodyAddRelForceAtRelPos(bodyId, force.x, force.y, force.z, pos.x, pos.y, pos.z);
	}
	
	public void addTorque(vec3 torque)
	{
		dBodyAddTorque(bodyId, torque.x, torque.y, torque.z);
	}

	void setForce(vec3 force)
	{
		dBodySetForce(bodyId, force.x, force.y, force.z);
	}
	
	void setTorque(vec3 torque)
	{
		dBodySetTorque(bodyId, torque.x, torque.y, torque.z);
	}
	
	@property
	{
		vec3 force()
		{
			return vec3(dBodyGetForce(bodyId)[0..3]);
		}
		
		vec3 torque()
		{
			return vec3(dBodyGetTorque(bodyId)[0..3]);
		}
	
		bool kinematic()
		{
			return !!dBodyIsKinematic(bodyId);
		}

		void kinematic(bool isKinematic)
		{
			isKinematic ? dBodySetKinematic(bodyId) : dBodySetDynamic(bodyId);
		}

		bool enabled()
		{
			return !!dBodyIsEnabled(bodyId);
		}

		void enabled(bool isEnabled)
		{
			isEnabled ? dBodyEnable(bodyId) : dBodyDisable(bodyId);
		}

		bool autoDisable()
		{
			return !!dBodyGetAutoDisableFlag(bodyId);
		}

		void autoDisable(bool autoDisable)
		{
			dBodySetAutoDisableFlag(bodyId, autoDisable);
		}
		
		float autoDisableLinearThreshold()
		{
			return dBodyGetAutoDisableLinearThreshold(bodyId);
		}
		
		void autoDisableLinearThreshold(float threshold)
		{
			dBodySetAutoDisableLinearThreshold(bodyId, threshold);
		}
		
		float autoDisableAngularThreshold()
		{
			return dBodyGetAutoDisableAngularThreshold(bodyId);
		}
		
		void autoDisableAngularThreshold(float threshold)
		{
			dBodySetAutoDisableAngularThreshold(bodyId, threshold);
		}
		
		float autoDisableTime()
		{
			return dBodyGetAutoDisableTime(bodyId);
		}
		
		void autoDisableTime(float time)
		{
			dBodySetAutoDisableTime(bodyId, time);
		}
		
		bool affectedByGravity()
		{
			return !!dBodyGetGravityMode(bodyId);
		}
		
		void affectedByGravity(bool affectedByGravity)
		{
			dBodySetGravityMode(bodyId, affectedByGravity);
		}
	}

	public void initialize()
	{
		assert(transform.isRoot, "Rigid body transforms should be root");
	
		previousStepTransformation = currentStepTransformation = transform.localTransformation;

		auto position = currentStepTransformation.position;
		auto rotation = currentStepTransformation.rotation;
		dBodySetPosition(bodyId, position.x, position.y, position.z);
		dBodySetQuaternion(bodyId, rotation.quaternion.wxyz.vector);
	}

	public void frameUpdate()
	{
		transform.localTransformation = Transformation.interpolate(previousStepTransformation, currentStepTransformation, world.phase);
	}

	public void physicsPreStepUpdate()
	{
		previousStepTransformation = currentStepTransformation;
	}

	private void onMoved()
	{
		currentStepTransformation.position.vector[] = positionStore[];
		currentStepTransformation.rotation.quaternion = vec4(rotationStore).yzwx;
	}

	private static extern(C) void bodyMovedCallback(dBodyID bodyId)
	{
		auto movedBody = cast(RigidBody)dBodyGetData(bodyId);
		movedBody.onMoved();
	}
}

private struct PhysicsMaterialProperties
{
	@optional:

	float friction = 1;
	float bounciness = 0;
	
	@property
	{
		int flags() const nothrow @nogc
		{
			return
				//dContactFDir1							| // Auto generate friction direction for now
				(dContactBounce * (bounciness != 0));
		}
	}
	
	private dSurfaceParameters toOdeParams() const nothrow @nogc
	{
		dSurfaceParameters params;
		params.mode = flags;
		params.mu = friction;
		params.rho = 0;
		params.rho2 = 0;
		params.rhoN = 0;
		params.bounce = bounciness;
		return params;
	}
	
	static PhysicsMaterialProperties combine(PhysicsMaterialProperties m1, PhysicsMaterialProperties m2) nothrow @nogc
	{
		import std.algorithm.comparison : max;
	
		return PhysicsMaterialProperties
		(
			(m1.friction + m2.friction) * 0.5f,
			max(m1.bounciness, m2.bounciness)
		);
	}
}

final class PhysicsMaterial : Component
{
	private PhysicsMaterialProperties properties;
	
	static PhysicsMaterial fromRepresentation(PhysicsMaterialProperties properties)
	{
		auto material = new PhysicsMaterial;
		material.properties = properties;
		return material;
	}
	
	PhysicsMaterialProperties toRepresentation()
	{
		return properties;
	}
}

abstract class CollisionGeometry : Component
{
	private @dependency PhysicsMaterial material;
	private dGeomID _geomId;
	protected RigidBody rigidBody; // Can be null

	~this()
	{
		dGeomDestroy(_geomId);
	}
	
	protected @ignore @property
	{
		dGeomID geomId()
		{
			return _geomId;
		}
		
		void geomId(dGeomID id)
		{
			assert(_geomId is null);
			_geomId = id;
			dGeomSetData(_geomId, cast(void*)this);
		}
	}
	
	//For use in subclass constructors..
	protected final @property worldCollisionSpaceId()
	{
		return scene.components.firstOrAdd!CollisionWorld.spaceId;
	}
}

abstract class PlaceableCollisionGeometry : CollisionGeometry
{
	@optional:

	protected @dependency Transform transform;
	private Transform.ChangedRegistration transformChanged;
	
	private vec3 _offsetPosition;
	private quat _offsetRotation;
	
	
	public final @property
	{
		vec3 offsetPosition() const
		{
			return _offsetPosition;
		}
		
		void offsetPosition(vec3 offset)
		{
			_offsetPosition = offset;
			
			if(rigidBody !is null)
			{
				dGeomSetOffsetPosition(geomId, offset.x, offset.y, offset.z);
			}
		}
		
		quat offsetRotation() const
		{
			return _offsetRotation;
		}
		
		void offsetRotation(quat offset)
		{
			_offsetRotation = offset;
			
			if(rigidBody !is null)
			{
				auto rot = offset.quaternion.wxyz.vector;
				dGeomSetOffsetQuaternion(geomId, rot);
			}
		}
	}

	private void initialize()
	{
		rigidBody = owner.components.first!RigidBody;
		
		if(rigidBody is null)
		{
			transformChanged = transform.onWorldTransformChanged.register(&updateGeomTransform);
		}
		else
		{
			dGeomSetBody(geomId, rigidBody.bodyId);
			
			// The setter will now pass it through to ODE due to rigidBody !is null
			offsetPosition = offsetPosition;
			offsetRotation = offsetRotation;
		}
	}
	
	private void updateGeomTransform(Transform transform)
	{
		auto transformation = transform.worldTransformation;
		auto pos = transformation.position;
		dGeomSetPosition(geomId, pos.x, pos.y, pos.z);
		auto rot = transformation.rotation.quaternion.wxyz.vector;
		dGeomSetQuaternion(geomId, rot);
	}
}

final class CollisionSphere : PlaceableCollisionGeometry
{
	@optional:

	this()
	{
		geomId = dCreateSphere(worldCollisionSpaceId, 1);
	}
	
	@property
	{
		float radius()
		{
			return dGeomSphereGetRadius(geomId);
		}
		
		void radius(float radius)
		{
			dGeomSphereSetRadius(geomId, radius);
		}
	}
}

final class CollisionBox : PlaceableCollisionGeometry
{
	@optional:

	this()
	{
		geomId = dCreateBox(worldCollisionSpaceId, 1, 1, 1);
	}
	
	@property
	{
		vec3 extent()
		{
			vec4 result;
			dGeomBoxGetLengths(geomId, result.vector);
			return result.xyz * 0.5f;
		}
		
		void extent(vec3 extent)
		{
			extent *= 2;
			dGeomBoxSetLengths(geomId, extent.x, extent.y, extent.z);
		}
	}
}

final class CollisionCapsule : PlaceableCollisionGeometry
{
	@optional:

	private vec2 rl = vec2(1, 1);

	this()
	{
		geomId = dCreateCapsule(worldCollisionSpaceId, rl.x, rl.y);
	}
	
	@property
	{
		float radius() const
		{
			return rl.x;
		}
		
		void radius(float r)
		{
			rl.x = r;
			dGeomCapsuleSetParams(geomId, r, rl.y);
		}
		
		float length() const
		{
			return rl.y;
		}
		
		void length(float l)
		{
			rl.y = l;
			dGeomCapsuleSetParams(geomId, rl.x, l);
		}
	}
}

final class CollisionCylinder : PlaceableCollisionGeometry
{
	@optional:

	private vec2 rl = vec2(1, 1);

	this()
	{
		geomId = dCreateCylinder(worldCollisionSpaceId, rl.x, rl.y);
	}
	
	@property
	{
		float radius() const
		{
			return rl.x;
		}
		
		void radius(float r)
		{
			rl.x = r;
			dGeomCylinderSetParams(geomId, r, rl.y);
		}
		
		float length() const
		{
			return rl.y;
		}
		
		void length(float l)
		{
			rl.y = l;
			dGeomCylinderSetParams(geomId, rl.x, l);
		}
	}
}

public final class PhysicsWorld : SceneComponent
{
	enum SteppingMode
	{
		Fast,
		Accurate
	}

	private dWorldID worldId;
	private float _stepSize = 0.05f;;

	@byName
	SteppingMode steppingMode = SteppingMode.Fast;

	private @dependency Time time;
	private float accumulator = 0;

	this()
	{
		worldId = dWorldCreate();

		gravity = vec3(0, -9.81f, 0);
		autoDisable = true;
	}

	~this()
	{
		dWorldDestroy(worldId);
	}

	public void frameUpdate()
	{
		accumulator += time.delta;

		//TODO: Max steps per frame
		while(accumulator >= stepSize)
		{
			scene.rootDispatcher.physicsPreStepUpdate();

			final switch(steppingMode)
			{
				case SteppingMode.Accurate:	dWorldStep(worldId, stepSize); break;
				case SteppingMode.Fast:		dWorldQuickStep(worldId, stepSize); break;
			}

			scene.rootDispatcher.physicsPostStepUpdate();

			accumulator -= stepSize;
		}
	}

	@property
	{
		void gravity(vec3 gravity)
		{
			dWorldSetGravity(worldId, gravity.x, gravity.y, gravity.z);
		}

		vec3 gravity()
		{
			dVector3 retVal;
			dWorldGetGravity(worldId, retVal);
			return vec3(retVal[0 .. 3]);
		}

		void errorCorrection(float erp)
		{
			//TODO: Range checking
			dWorldSetERP(worldId, erp);
		}

		float errorCorrection()
		{
			return dWorldGetERP(worldId);
		}

		void constraintForceMixing(float cfm)
		{
			//TODO: Range checking
			dWorldSetCFM(worldId, cfm);
		}

		float constraintForceMixing()
		{
			return dWorldGetCFM(worldId);
		}

		void autoDisable(bool autoDisable)
		{
			dWorldSetAutoDisableFlag(worldId, autoDisable);
		}

		bool autoDisable()
		{
			return !!dWorldGetAutoDisableFlag(worldId);
		}

		void autoDisableLinearThreshold(float treshold)
		{
			dWorldSetAutoDisableLinearThreshold(worldId, treshold);
		}

		float autoDisableLinearThreshold()
		{
			return dWorldGetAutoDisableLinearThreshold(worldId);
		}

		void autoDisableAngularTreshold(float treshold)
		{
			dWorldSetAutoDisableAngularThreshold(worldId, treshold);
		}

		float autoDisableAngularTreshold()
		{
			return dWorldGetAutoDisableAngularThreshold(worldId);
		}

		void autoDisableSteps(int steps)
		{
			dWorldSetAutoDisableSteps(worldId, steps);
		}

		int autoDisableSteps()
		{
			return dWorldGetAutoDisableSteps(worldId);
		}

		void autoDisableTime(float time)
		{
			dWorldSetAutoDisableTime(worldId, time);
		}

		float autoDisableTime()
		{
			return dWorldGetAutoDisableTime(worldId);
		}

		void fastStepIterations(int iterations)
		{
			dWorldSetQuickStepNumIterations(worldId, iterations);
		}

		int fastStepIterations()
		{
			return dWorldGetQuickStepNumIterations(worldId);
		}

		void fastStepOverRelaxation(float overRelaxation)
		{
			dWorldSetQuickStepW(worldId, overRelaxation);
		}

		float fastStepOverRelaxation()
		{
			return dWorldGetQuickStepW(worldId);
		}

		void stepSize(float stepSize)
		{
			//TODO: Range check
			_stepSize = stepSize;
		}

		float stepSize()
		{
			return _stepSize;
		}

		void linearDamping(float damping)
		{
			dWorldSetLinearDamping(worldId, damping);
		}

		float linearDamping()
		{
			return dWorldGetLinearDamping(worldId);
		}

		void angularDamping(float damping)
		{
			dWorldSetAngularDamping(worldId, damping);
		}

		float angularDamping()
		{
			return dWorldGetAngularDamping(worldId);
		}

		void linearDampingTreshold(float treshold)
		{
			dWorldSetLinearDampingThreshold(worldId, treshold);
		}

		float linearDampingTreshold()
		{
			return dWorldGetLinearDampingThreshold(worldId);
		}

		void angularDampingTreshold(float treshold)
		{
			dWorldSetAngularDampingThreshold(worldId, treshold);
		}

		float angularDampingTreshold()
		{
			return dWorldGetAngularDampingThreshold(worldId);
		}

		void maxAngularSpeed(float speed)
		{
			dWorldSetMaxAngularSpeed(worldId, speed);
		}

		float maxAngularSpeed()
		{
			return dWorldGetMaxAngularSpeed(worldId);
		}

		void maxContactCorrectingVelocity(float velocity)
		{
			dWorldSetContactMaxCorrectingVel(worldId, velocity);
		}

		float maxContactCorrectingVelocity()
		{
			return dWorldGetContactMaxCorrectingVel(worldId);
		}

		void contactSurfaceDepth(float depth)
		{
			dWorldSetContactSurfaceLayer(worldId, depth);
		}

		float contactSurfaceDepth()
		{
			return dWorldGetContactSurfaceLayer(worldId);
		}

		float phase()
		{
			return accumulator / stepSize;
		}
	}

	private dBodyID createBody()
	{
		return dBodyCreate(worldId);
	}
}

final class CollisionWorld : SceneComponent
{
	private @dependency(Dependency.Direction.Unordered) PhysicsWorld physicsWorld;

	private dSpaceID spaceId;
	private dJointGroupID contactJointGroupId;
	
	this()
	{
		//TODO: Support QuadTreeSpace
		spaceId = dHashSpaceCreate(null);
		contactJointGroupId = dJointGroupCreate(0);
	}
	
	~this()
	{
		dJointGroupDestroy(contactJointGroupId);
		dSpaceDestroy(spaceId);
	}
	
	void physicsPreStepUpdate()
	{
		dSpaceCollide(spaceId, cast(void*)this, &geometryNearCallback);
	}
	
	void physicsPostStepUpdate()
	{
		dJointGroupEmpty(contactJointGroupId);
	}
	
	private static extern(C) void geometryNearCallback(void* data, dGeomID geom1, dGeomID geom2) nothrow @nogc
	{
		//TODO: Support nested spaces.
		auto _this = cast(CollisionWorld)data;
		
		//TODO: I have no idea if this is a sensible amount..
		enum MaxContacts = 3;
		static assert(MaxContacts < ushort.max);
		dContactGeom[MaxContacts] contacts;
		
		auto actualContacts = dCollide(geom1, geom2, contacts.length, contacts.ptr, dContactGeom.sizeof);
		
		foreach(contact; contacts[0 .. actualContacts])
		{
			_this.createContactJoint(contact);
		}
	}
	
	private void createContactJoint(dContactGeom contactGeom) nothrow @nogc
	{
		auto geom1 = cast(CollisionGeometry)dGeomGetData(contactGeom.g1);
		auto geom2 = cast(CollisionGeometry)dGeomGetData(contactGeom.g2);
		
		auto combinedMaterial = PhysicsMaterialProperties.combine(geom1.material.properties, geom2.material.properties);
	
		auto contact = dContact
		(
			combinedMaterial.toOdeParams,
			contactGeom
		);
		
		auto joint = dJointCreateContact(physicsWorld.worldId, contactJointGroupId, &contact);
		
		auto bodyId1 = geom1.rigidBody is null ? null : geom1.rigidBody.bodyId;
		auto bodyId2 = geom2.rigidBody is null ? null : geom2.rigidBody.bodyId;
		
		dJointAttach(joint, bodyId1, bodyId2);
	}
}

shared static this()
{
	DerelictODE.load();
	//NOTE: Initializing ODE in this way binds it to the main thread. Will cause breakage if the ECS becomes multithreaded 
	dInitODE();
}

shared static ~this()
{
	dCloseODE();
	DerelictODE.unload();
}