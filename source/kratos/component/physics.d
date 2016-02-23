module kratos.component.physics;

import kratos.ecs.scene : SceneComponent;
import kratos.ecs.entity : Component;
import kratos.ecs.component : Dependency, dependency, byName;
import kratos.component.time : Time;
import kratos.component.transform : Transform, Transformation;
import kgl3n.vector : vec3, vec4;
import derelict.ode.ode;

public final class RigidBody : Component
{
	private dBodyID bodyId;
	private @dependency PhysicsWorld world;
	private @dependency(Dependency.Direction.Write) Transform transform;
	private Transformation previousStepTransformation;
	private Transformation currentStepTransformation;
	private float[] positionStore;
	private float[] rotationStore;

	public void addForce(vec3 force)
	{
		dBodyAddForce(bodyId, force.x, force.y, force.z);
	}

	@property
	{
		bool kinematic()
		{
			return dBodyIsKinematic(bodyId) != 0;
		}

		void kinematic(bool isKinematic)
		{
			isKinematic ? dBodySetKinematic(bodyId) : dBodySetDynamic(bodyId);
		}

		bool enabled()
		{
			return dBodyIsEnabled(bodyId) != 0;
		}

		void enabled(bool isEnabled)
		{
			isEnabled ? dBodyEnable(bodyId) : dBodyDisable(bodyId);
		}

		bool autoDisable()
		{
			return dBodyGetAutoDisableFlag(bodyId) != 0;
		}

		void autoDisable(bool autoDisable)
		{
			dBodySetAutoDisableFlag(bodyId, autoDisable);
		}
	}

	public void initialize()
	{
		bodyId = world.createBody();
		dBodySetData(bodyId, cast(void*)this);
		dBodySetMovedCallback(bodyId, &bodyMovedCallback);
		previousStepTransformation = currentStepTransformation = transform.localTransformation;

		auto position = currentStepTransformation.position;
		auto rotation = currentStepTransformation.rotation;
		dBodySetPosition(bodyId, position.x, position.y, position.z);
		dBodySetQuaternion(bodyId, rotation.quaternion.wxyz.vector);

		positionStore = dBodyGetPosition(bodyId)[0 .. 3];
		rotationStore = dBodyGetRotation(bodyId)[0 .. 4];
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
	private float accumulator;

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

	public void initialize()
	{
		if(accumulator is typeof(accumulator).init)
		{
			accumulator = _stepSize;
		}
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

		void autoDisableLinearTreshold(float treshold)
		{
			dWorldSetAutoDisableLinearThreshold(worldId, treshold);
		}

		float autoDisableLinearTreshold()
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