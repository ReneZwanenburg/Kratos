module kratos.component.registrations;

import kratos.ecs.component : registerComponent;

import kratos.component.camera : Camera;
import kratos.component.light : DirectionalLight, PointLight;
import kratos.component.meshrenderer : MeshRenderer, MeshRendererPartitioning;
import kratos.component.simplemovement : SimpleMovement;
import kratos.component.time : Time;
import kratos.component.transform : Transform;

static this()
{
	import std.experimental.logger : info;
	info("Registering serializers");

	registerComponent!Camera;
	registerComponent!DirectionalLight;
	registerComponent!PointLight;
	registerComponent!MeshRenderer;
	registerComponent!SimpleMovement;
	registerComponent!Time;
	registerComponent!Transform;
}