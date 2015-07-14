module kratos.component.simplemovement;

import kratos.ecs;
import kratos.input;
import kratos.component.transform;
import kratos.time : Time;
import kgl3n.vector;
import kgl3n.quaternion;
import kgl3n.math;

final class SimpleMovement : Component
{
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

		auto forward = (transform.rotation * vec3(0, 0, -1)) * speed * Time.delta;
		auto right = (transform.rotation * vec3(1, 0, 0)) * speed * Time.delta;
		auto up = (transform.rotation * vec3(0, 1, 0)) * speed * Time.delta;

		if(keyboard["W"].pressed)
		{
			transform.position = transform.position + forward;
		}
		if(keyboard["S"].pressed)
		{
			transform.position = transform.position - forward;
		}
		if(keyboard["A"].pressed)
		{
			transform.position = transform.position - right;
		}
		if(keyboard["D"].pressed)
		{
			transform.position = transform.position + right;
		}
		if(keyboard["Q"].pressed)
		{
			transform.position = transform.position + up;
		}
		if(keyboard["Z"].pressed)
		{
			transform.position = transform.position - up;
		}
	}
}