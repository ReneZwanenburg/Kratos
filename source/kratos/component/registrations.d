module kratos.component.registrations;

import kratos.ecs.component : registerComponent;

import kratos.component.camera : Camera;
import kratos.component.light : DirectionalLight;
import kratos.component.meshrenderer : MeshRenderer, MeshRendererPartitioning;
import kratos.component.physics : PhysicsWorld, RigidBody, CollisionSphere, CollisionBox, CollisionCapsule, CollisionCylinder;
import kratos.component.renderer : Renderer;
import kratos.component.simplemovement : SimpleMovement;
import kratos.component.time : Time;
import kratos.component.transform : Transform;

static this()
{
	registerComponent!Camera;
	registerComponent!DirectionalLight;
	registerComponent!MeshRenderer;
	registerComponent!PhysicsWorld;
	registerComponent!RigidBody;
	registerComponent!CollisionSphere;
	registerComponent!CollisionBox;
	registerComponent!CollisionCapsule;
	registerComponent!CollisionCylinder;
	registerComponent!SimpleMovement;
	registerComponent!Time;
	registerComponent!Transform;
}