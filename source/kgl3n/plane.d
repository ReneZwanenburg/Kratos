module kgl3n.plane;

import kgl3n.vector;
import kgl3n.math : almostEqual;

import std.traits : isFloatingPoint;

/// Base template for all plane-types.
/// Params:
/// type = all values get stored as this type (must be floating point)
struct PlaneT(type = float)
if(isFloatingPoint!type)
{
	alias vt = Vector!(type, 4); /// Convenience alias to the corresponding vector type.

    vt p;

    @safe pure nothrow:

    /// Constructs the plane from a 4-dimensional vector
    this(vt p)
	{
        this.p = p;
    }

    /// Normalizes the plane inplace.
    void normalize()
	{
        p *= 1 / p.xyz.magnitude;
    }

    /// Returns a normalized copy of the plane.
    @property PlaneT normalized() const
	{
        PlaneT ret = this;
        ret.normalize();
        return ret;
    }

	@property const(Vector!(type, 3)) normal()
	{
		return p.xyz;
	}

    /// Returns the distance from a point to the plane.
    /// Note: the plane $(RED must) be normalized, the result can be negative.
    auto distance(T)(T point) const
	if(isVector!T)
	{
        return dot(point.homogeneousPoint, p);
    }

    /// Returns the distance from a point to the plane.
    /// Note: the plane does not have to be normalized, the result can be negative.
    auto ndistance(T)(T point) const
	if(isVector!T)
	{
		return normalized.distance(point);
    }
}

alias PlaneT!(float) Plane;

enum isPlane(T) = is(T == PlaneT!Args, Args...);


unittest
{
	auto p = Plane(vec4(0.0f, 1.0f, 2.0f, 3.0f));
	assert(p.p == vec4(0.0f, 1.0f, 2.0f, 3.0f));
	
	p.p.x = 4.0f;
	assert(p.normal == vec3(4.0f, 1.0f, 2.0f));
}

unittest
{
	auto p = Plane(vec4(0.0f, 1.0f, 2.0f, 3.0f));
	auto pn = p.normalized();
	assert(pn.normal == vec3(0.0f, 1.0f, 2.0f).normalized);
	assert(almostEqual(pn.p.w, 3.0f/vec3(0.0f, 1.0f, 2.0f).magnitude));
	p.normalize();
	assert(p == pn);
}

unittest
{
	auto p = Plane(vec4(-1.0f, 4.0f, 19.0f, -10.0f));
	assert(almostEqual(p.ndistance(vec3(5.0f, -2.0f, 0.0f)), -1.182992));
	assert(almostEqual(p.ndistance(vec3(5.0f, -2.0f, 0.0f)),
	                   p.normalized.distance(vec3(5.0f, -2.0f, 0.0f))));
}