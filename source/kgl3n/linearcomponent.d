module kgl3n.linearcomponent;

import kgl3n.vector;

struct Line
{
	vec3 p, d;
}

struct Ray
{
	vec3 p, d;
}

struct LineSegment
{
	vec3 p, d;
	float t;
}