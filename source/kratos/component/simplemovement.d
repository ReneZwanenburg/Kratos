module kratos.component.simplemovement;

import kratos.ecs;
import kratos.input;
import kratos.component.transform;
import kgl3n.vector;
import kgl3n.quaternion;
import kgl3n.math;

final class SimpleMovement : Component
{
	mixin RegisterComponent;

	@optional:
	float sensitivity = .002f;
	float speed = 1;
	private @dependency Transform transform;

	vec3 ypr;

	void frameUpdate()
	{
		ypr.x += -mouse.xAxis.value * sensitivity;
		ypr.y += -mouse.yAxis.value * sensitivity;
		ypr.y = ypr.y.clamp(-PI / 2.5, PI / 2.5);

		transform.rotation = quat.eulerRotation(ypr);

		auto forward = transform.worldMatrix[2].xyz;

		if(keyboard["Up"].pressed)
		{
			transform.position = transform.position + forward * speed;
		}
		if(keyboard["Down"].pressed)
		{
			transform.position = transform.position - forward * speed;
		}
	}
}