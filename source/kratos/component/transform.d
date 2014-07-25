module kratos.component.transform;

import kratos.entity;
import gl3n.linalg;


final class Transform : Component
{
	private Transform	_parent		= null;
	private vec3		_position	= vec3(0);
	private quat		_rotation	= quat.identity;
	//TODO: Decide if non-uniform scaling should be supported
	private float		_scale		= 1;
}