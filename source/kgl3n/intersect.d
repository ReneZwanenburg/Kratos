module kgl3n.intersect;

import kgl3n.aabb;
import kgl3n.frustum;
import kgl3n.linearcomponent;
import kgl3n.vector;

import std.algorithm.comparison : min, max;

bool testIntersection(in Line line, in AABB aabb)
{
	auto nInv = 1 / line.d;

	auto t1 = (aabb.min - line.p) * nInv;
	auto t2 = (aabb.max - line.p) * nInv;

	auto tMin = componentMin(t1, t2);
	auto tMax = componentMax(t1, t2);

	return min(tMax[0], tMax[1], tMax[2]) >= max(tMin[0], tMin[1], tMin[2]);
}

bool testIntersection(in Ray ray, in AABB aabb)
{
	auto nInv = 1 / ray.d;

	auto t1 = (aabb.min - ray.p) * nInv;
	auto t2 = (aabb.max - ray.p) * nInv;
	
	auto tMin = componentMin(t1, t2);
	auto tMax = componentMax(t1, t2);

	auto minTMax = min(tMax[0], tMax[1], tMax[2]);

	return minTMax >= 0 && minTMax >= max(tMin[0], tMin[1], tMin[2]);
}

bool testIntersection(in Frustum frustum, in AABB aabb)
{
	auto hextent = aabb.halfExtent;
	auto center = aabb.center;
	
	foreach(plane; frustum.planes)
	{
		float d = dot(center, plane.p.xyz);
		float r = dot(hextent, abs(plane.p.xyz));
		
		if(d + r < -plane.p.w)
		{
			return false;
		}
	}
	
	return true;
}