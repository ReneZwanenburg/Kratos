﻿module kratos.component.simplemovement;

import kratos.entity;
import kratos.input;
import kratos.component.transform;
import kgl3n.vector;
import kgl3n.quaternion;
import kgl3n.math;

final class SimpleMovement : Component
{
	float sensitivity = .002f;
	private @dependency Transform transform;

	private vec3 ypr;

	void frameUpdate()
	{
		ypr.x += -mouse.xAxis.value * sensitivity;
		ypr.y += -mouse.yAxis.value * sensitivity;
		ypr.y = ypr.y.clamp(-PI / 2.5, PI / 2.5);

		transform.rotation = quat.eulerRotation(ypr);
	}
}