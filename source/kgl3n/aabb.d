module kgl3n.aabb;

import kgl3n.vector;
import kgl3n.math : almostEqual, min, max;
import std.range : isInputRange, ElementType;
import std.array;


/// Base template for all AABB-types.
/// Params:
/// type = all values get stored as this type
struct AABBT(type)
{
    alias at = type; /// Holds the internal type of the AABB.
    alias vt = Vector!(at, 3); /// Convenience alias to the corresponding vector type.

	vt min = vt(0); /// The minimum of the AABB (e.g. vt(0, 0, 0)).
	vt max = vt(0); /// The maximum of the AABB (e.g. vt(1, 1, 1)).

    @safe pure nothrow:

    /// Constructs the AABB around N points (all points will be part of the AABB).
    static AABBT fromPoints(Range)(Range points)
	if(isInputRange!Range && is(ElementType!Range : vt))
	{
        AABBT res;

        if(points.empty)
		{
            return res;
        }

        res.min = res.max = points.front;
		points.popFront();
		foreach(point; points)
		{
            res.expand(point);
        }
        
        return res;
    }

    unittest
	{
        AABB a = AABB(vt(0.0f, 1.0f, 2.0f), vt(1.0f, 2.0f, 3.0f));
        assert(a.min == vt(0.0f, 1.0f, 2.0f));
        assert(a.max == vt(1.0f, 2.0f, 3.0f));

        a = AABB.fromPoints([vt(0.0f, 0.0f, 0.0f), vt(-1.0f, 2.0f, 3.0f), vt(0.0f, 0.0f, 4.0f)]);
        assert(a.min == vt(-1.0f, 0.0f, 0.0f));
        assert(a.max == vt(0.0f, 2.0f, 4.0f));
        
        a = AABB.fromPoints([vt(1.0f, 1.0f, 1.0f), vt(2.0f, 2.0f, 2.0f)]);
        assert(a.min == vt(1.0f, 1.0f, 1.0f));
        assert(a.max == vt(2.0f, 2.0f, 2.0f));
    }

    /// Expands the AABB by another AABB. 
    void expand(AABBT b)
	{
		min = componentMin(min, b.min);
		max = componentMax(max, b.max);
    }

    /// Expands the AABB, so that $(I v) is part of the AABB.
    void expand(vt v)
	{
		min = componentMin(min, v);
		max = componentMax(max, v);
    }

    unittest
	{
        AABB a = AABB(vt(0.0f, 0.0f, 0.0f), vt(1.0f, 4.0f, 1.0f));
        AABB b = AABB(vt(2.0f, -1.0f, 2.0f), vt(3.0f, 3.0f, 3.0f));

        AABB c;
        c.expand(a);
        c.expand(b);
        assert(c.min == vt(0.0f, -1.0f, 0.0f));
        assert(c.max == vt(3.0f, 4.0f, 3.0f));

        c.expand(vt(12.0f, -12.0f, 0.0f));
        assert(c.min == vt(0.0f, -12.0f, 0.0f));
        assert(c.max == vt(12.0f, 4.0f, 3.0f));
    }

    /// Returns true if the AABBs intersect.
    /// This also returns true if one AABB lies inside another.
    bool intersects(AABBT box) const
	{
        return (min.x < box.max.x && max.x > box.min.x) &&
               (min.y < box.max.y && max.y > box.min.y) &&
               (min.z < box.max.z && max.z > box.min.z);
    }

    unittest
	{
        assert(AABB(vt(0.0f, 0.0f, 0.0f), vt(1.0f, 1.0f, 1.0f)).intersects(
               AABB(vt(0.5f, 0.5f, 0.5f), vt(3.0f, 3.0f, 3.0f))));

        assert(AABB(vt(0.0f, 0.0f, 0.0f), vt(1.0f, 1.0f, 1.0f)).intersects(
               AABB(vt(0.5f, 0.5f, 0.5f), vt(0.7f, 0.7f, 0.7f))));

        assert(!AABB(vt(0.0f, 0.0f, 0.0f), vt(1.0f, 1.0f, 1.0f)).intersects(
                AABB(vt(1.5f, 1.5f, 1.5f), vt(3.0f, 3.0f, 3.0f))));
    }

    /// Returns the extent of the AABB (also sometimes called size).
    @property vt extent() const
	{
        return max - min;
    }

    /// Returns the half extent.
    @property vt halfExtent() const
	{
        return 0.5 * extent;
    }

    unittest
	{
        AABB a = AABB(vt(0.0f, 0.0f, 0.0f), vt(1.0f, 1.0f, 1.0f));
        assert(a.extent == vt(1.0f, 1.0f, 1.0f));
        assert(a.halfExtent == 0.5 * a.extent);

        AABB b = AABB(vt(0.2f, 0.2f, 0.2f), vt(1.0f, 1.0f, 1.0f));
        assert(b.extent == vt(0.8f, 0.8f, 0.8f));
        assert(b.halfExtent == 0.5 * b.extent);
        
    }

    /// Returns the area of the AABB.
    @property at area() const
	{
        vt e = extent;
        return 2.0 * (e.x * e.y + e.x * e.z + e.y * e.z);
    }

    unittest
	{
        AABB a = AABB(vt(0.0f, 0.0f, 0.0f), vt(1.0f, 1.0f, 1.0f));
        assert(a.area == 6);

        AABB b = AABB(vt(0.2f, 0.2f, 0.2f), vt(1.0f, 1.0f, 1.0f));
        assert(almostEqual(b.area, 3.84f));

        AABB c = AABB(vt(0.2f, 0.4f, 0.6f), vt(1.0f, 1.0f, 1.0f));
        assert(almostEqual(c.area, 2.08f));
    }

    /// Returns the center of the AABB.
    @property vt center() const
	{
        return 0.5 * (max + min);
    }

    unittest
	{
        AABB a = AABB(vt(0.5f, 0.5f, 0.5f), vt(1.0f, 1.0f, 1.0f));
        assert(a.center == vt(0.75f, 0.75f, 0.75f));
    }

    /// Returns all vertices of the AABB, basically one vt per corner.
    @property vt[8] vertices() const
	{
        return
		[
            vt(min.x, min.y, min.z),
            vt(min.x, min.y, max.z),
            vt(min.x, max.y, min.z),
            vt(min.x, max.y, max.z),
            vt(max.x, min.y, min.z),
            vt(max.x, min.y, max.z),
            vt(max.x, max.y, min.z),
            vt(max.x, max.y, max.z),
        ];
    }
}

alias AABBT!(float) AABB;
