module kratos.component.registrations;

import kratos.ecs.component : registerComponent;

import kratos.component.camera : Camera;
import kratos.component.meshrenderer : MeshRenderer, MeshRendererPartitioning;
import kratos.component.simplemovement : SimpleMovement;
import kratos.component.transform : Transform;

static this()
{
	registerComponent!Camera;
	registerComponent!MeshRenderer;
	registerComponent!MeshRendererPartitioning;
	registerComponent!SimpleMovement;
	registerComponent!Transform;
}