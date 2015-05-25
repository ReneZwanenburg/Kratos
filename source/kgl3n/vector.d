module kgl3n.vector;

import kgl3n.util;
import std.algorithm : min, max, among;

import vibe.data.serialization : optional;

/// Base template for all vector-types.
/// Params:
/// type = all values get stored as this type
/// dimension = specifies the dimension of the vector, can be 1, 2, 3 or 4
/// Examples:
/// ---
/// alias Vector!(int, 3) vec3i;
/// alias Vector!(float, 4) vec4;
/// alias Vector!(real, 2) vec2r;
/// ---
struct Vector(type, size_t dimension_)
{
	@optional:

	static assert(dimension > 0, "0 dimensional vectors don't exist.");

	alias vt = type; /// Holds the internal type of the vector.
	enum dimension = dimension_; ///Holds the dimension of the vector.
	alias opDollar = dimension;
	
	vt[dimension] vector = 0; /// Holds all coordinates, length conforms dimension.
	alias vector this;
	
	/// Returns a pointer to the coordinates.
	@property auto ptr()
	{
		return vector.ptr;
	}
	
	/// Returns the current vector formatted as string, useful for printing the vector.
	@property string toString()
	{
		import std.string : format;
		return format("%s", vector);
	}

	typeof(vector) toRepresentation()
	{
		return vector;
	}

	//TODO: Change Vibe's serializer to support toRepresentation without fromRepresentation
	static Vector fromRepresentation(typeof(vector) vector)
	{
		return Vector(vector);
	}
	
	@safe pure nothrow:
	
	/// static properties to access the values.
	@property ref inout(vt) x() inout { return vector[0]; }
	alias u = x; /// ditto
	alias s = x; /// ditto
	alias r = x; /// ditto
	static if(dimension >= 2)
	{
		@property ref inout(vt) y() inout { return vector[1]; } /// ditto
		alias v = y; /// ditto
		alias t = y; /// ditto
		alias g = y; /// ditto
	}
	static if(dimension >= 3)
	{
		@property ref inout(vt) z() inout { return vector[2]; } /// ditto
		alias b = z; /// ditto
		alias p = z; /// ditto
	}
	static if(dimension >= 4)
	{
		@property ref inout(vt) w() inout { return vector[3]; } /// ditto
		alias a = w; /// ditto
		alias q = w; /// ditto
	}
	
	static if(dimension == 2)
	{
		enum Vector e1 = Vector(1, 0); /// canonical basis for Euclidian space
		enum Vector e2 = Vector(0, 1); /// ditto
	}
	else static if(dimension == 3)
	{
		enum Vector e1 = Vector(1, 0, 0); /// canonical basis for Euclidian space
		enum Vector e2 = Vector(0, 1, 0); /// ditto
		enum Vector e3 = Vector(0, 0, 1); /// ditto
	}
	else static if(dimension == 4)
	{
		enum Vector e1 = Vector(1, 0, 0, 0); /// canonical basis for Euclidian space
		enum Vector e2 = Vector(0, 1, 0, 0); /// ditto
		enum Vector e3 = Vector(0, 0, 1, 0); /// ditto
		enum Vector e4 = Vector(0, 0, 0, 1); /// ditto
	}

	private enum isCompatibleVector(T) = is(T == Vector!(vt, D), D...) && T.dimension <= dimension;

	private void construct(int i, T, Tail...)(T head, Tail tail)
	{
		import std.traits : isDynamicArray, isStaticArray;

		static if(i >= dimension)
		{
			static assert(false, "Too many arguments passed to constructor");
		}
		else static if(is(T : vt))
		{
			vector[i] = head;
			construct!(i + 1)(tail);
		}
		else static if(isDynamicArray!T)
		{
			static assert((Tail.length == 0) && (i == 0), "dynamic array can not be passed together with other arguments");
			vector[] = head[];
		}
		else static if(isStaticArray!T)
		{
			vector[i .. i + T.length] = head[];
			construct!(i + T.length)(tail);
		}
		else static if(isCompatibleVector!T)
		{
			vector[i .. i + T.dimension] = head.vector[];
			construct!(i + T.dimension)(tail);
		}
		else
		{
			static assert(false, "Vector constructor argument must be of type " ~ vt.stringof ~ " or Vector, not " ~ T.stringof);
		}
	}

	// terminate
	private void construct(int i)() { }
	
	/// Constructs the vector.
	/// If a single value is passed the vector, the vector will be cleared with this value.
	/// If a vector with a higher dimension is passed the vector will hold the first values up to its dimension.
	/// If mixed types are passed they will be joined together (allowed types: vector, static array, $(I vt)).
	/// Examples:
	/// ---
	/// vec4 v4 = vec4(1.0f, vec2(2.0f, 3.0f), 4.0f);
	/// vec3 v3 = vec3(v4); // v3 = vec3(1.0f, 2.0f, 3.0f);
	/// vec2 v2 = v3.xy; // swizzling returns a static array.
	/// vec3 v3_2 = vec3(1.0f); // vec3 v3_2 = vec3(1.0f, 1.0f, 1.0f);
	/// ---
	this(Args...)(Args args)
	{
		construct!(0)(args);
	}
	
	/// ditto
	this(T)(T vec)
	if(isVector!T && is(T.vt : vt) && (T.dimension >= dimension))
	{
		foreach(i; TupleRange!(0, dimension))
		{
			vector[i] = vec.vector[i];
		}
	}
	
	/// ditto
	this()(vt value)
	{
		clear(value);
	}
	
	/// Returns true if all values are not nan and finite, otherwise false.
	@property bool isFinite() const
	{
		import std.traits : isIntegral;

		static if(isIntegral!type)
		{
			return true;
		}
		else
		{
			import std.math : isFinite;
			import std.algorithm : all;
			return vector[].all!isFinite;
		}
	}
	
	/// Sets all values of the vector to value.
	void clear(vt value)
	{
		vector[] = value;
	}
	
	template coordToIndex(char c)
	{
		static if(c.among('x', 'r', 'u', 's'))
		{
			enum coordToIndex = 0;
		}
		else static if(c.among('y', 'g', 'v', 't'))
		{
			enum coordToIndex = 1;
		}
		else static if(c.among('z', 'b', 'p'))
		{
			static assert(dimension >= 3, "the " ~ c ~ " property is only available on vectors with a third dimension.");
			enum coordToIndex = 2;
		}
		else static if(c.among('w', 'a', 'q'))
		{
			static assert(dimension >= 4, "the " ~ c ~ " property is only available on vectors with a fourth dimension.");
			enum coordToIndex = 3;
		}
		else
		{
			static assert(false, "accepted coordinates are x, s, r, u, y, g, t, v, z, p, b, w, q and a not " ~ c ~ ".");
		}
	}
	
	static if(dimension >= 2)
	{
		void set(vt x, vt y)
		{
			vector[0] = x;
			vector[1] = y;
		}
	}
	static if(dimension >= 3)
	{
		void set(vt x, vt y, vt z)
		{
			set(x, y);
			vector[2] = z;
		}
	}
	static if(dimension >= 4)
	{
		void set(vt x, vt y, vt z, vt w)
		{
			set(x, y, z);
			vector[3] = w;
		}
	}

	
	/// Implements dynamic swizzling.
	/// Returns: a Vector
	@property Vector!(vt, s.length) opDispatch(string s)() const
	{
		Vector!(vt, s.length) ret;
		foreach(i; TupleRange!(0, s.length))
		{
			ret[i] = vector[coordToIndex!(s[i])];
		}
		return ret;
	}
	
	@property void opDispatch(string s)(Vector!(vt, s.length) v)
	{
		foreach(i; TupleRange!(0, s.length))
		{
			vector[coordToIndex!(s[i])] = v[i];
		}
	}
	
	/// Returns the squared magnitude of the vector.
	@property real sqrMagnitude() const
	{
		real temp = 0;
		
		foreach(index; TupleRange!(0, dimension))
		{
			temp += vector[index] * vector[index];
		}
		
		return temp;
	}
	
	/// Returns the magnitude of the vector.
	@property real magnitude() const
	{
		import std.math : sqrt;
		return sqrt(sqrMagnitude);
	}
	
	/// Normalizes the vector.
	void normalize()
	{
		real len = magnitude;
		
		if(len != 0)
		{
			foreach(index; TupleRange!(0, dimension))
			{
				vector[index] /= len;
			}
		}
	}
	
	/// Returns a normalized copy of the current vector.
	@property Vector normalized() const
	{
		Vector ret = this;
		ret.normalize();
		return ret;
	}
	
	Vector opUnary(string op : "-")() const
	{
		Vector ret;

		foreach(index; TupleRange!(0, dimension))
		{
			ret.vector[index] = -vector[index];
		}
		
		return ret;
	}
	
	Vector opBinary(string op, T)(T r) const
	if(is(T : vt))
	{
		return this.opBinary!(op)(Vector(r));
	}
	
	Vector opBinary(string op)(Vector r) const
	if(op.among("+", "-", "*", "/"))
	{
		Vector ret = this;
		mixin("ret"~op~"=r;");
		return ret;
	}
	
	auto opBinaryRight(string op, T)(T inp) const
	if(is(T : vt))
	{
		return Vector(inp).opBinary!(op)(this);
	}
	
	void opOpAssign(string op, T)(T r)
	if(is(T : vt))
	{
		opOpAssign!op(Vector(r));
	}
	
	void opOpAssign(string op)(Vector r)
	if(op.among("+", "-", "*", "/"))
	{
		foreach(index; TupleRange!(0, dimension))
		{
			mixin("vector[index]" ~ op ~ "= r.vector[index];");
		}
	}

	inout(vt[]) opSlice(size_t from, size_t to) inout
	{
		return vector[from..to];
	}
	
	inout(vt[]) opSlice() inout
	{
		return this[0..$];
	}

	ref inout(vt) opIndex(size_t index) inout
	in
	{
		assert(index < dimension);
	}
	body
	{
		return vector[index];
	}
	
	int opCmp(ref const Vector vec) const
	{
		foreach(i, a; vector)
		{
			if(a < vec.vector[i])
			{
				return -1;
			}
			else if(a > vec.vector[i])
			{
				return 1;
			}
		}
		
		// Vectors are the same
		return 0;
	}
	
	bool opCast(T : bool)() const {
		return isFinite;
	}
}

/// Calculates the product between two vectors.
@safe pure nothrow T.vt dot(T)(const T veca, const T vecb)
if(isVector!T)
{
	T.vt temp = 0;
	
	foreach(index; TupleRange!(0, T.dimension))
	{
		temp += veca.vector[index] * vecb.vector[index];
	}
	
	return temp;
}

@safe pure nothrow auto homogeneousPoint(T)(const T v)
if(isVector!T)
{
	static if(T.dimension == 4)
	{
		return v;
	}
	else
	{
		auto ret = Vector!(T.vt, 4)(v);
		ret.w = 1;
		return ret;
	}
}

@safe pure nothrow T componentOp(alias func, T)(T v1, T v2)
if(isVector!T)
{
	auto retVal = T.init;
	foreach(i; 0..T.dimension)
	{
		retVal.vector[i] = func(v1.vector[i], v2.vector[i]);
	}
	return retVal;
}

auto componentMin(T)(T v1, T v2) { return componentOp!min(v1, v2); }
auto componentMax(T)(T v1, T v2) { return componentOp!max(v1, v2); }

/// Calculates the cross product of two 3-dimensional vectors.
@safe pure nothrow T cross(T)(const T veca, const T vecb)
if(isVector!T && (T.dimension == 3))
{
	return T(veca.y * vecb.z - vecb.y * veca.z,
	         veca.z * vecb.x - vecb.z * veca.x,
	         veca.x * vecb.y - vecb.x * veca.y);
}

/// Calculates the distance between two vectors.
@safe pure nothrow T.vt distance(T)(const T veca, const T vecb)
if(isVector!T)
{
	return (veca - vecb).magnitude;
}

/// Pre-defined vector types, the number represents the dimension and the last letter the type (none = float, d = double, i = int).
alias Vector!(float, 2) vec2;
alias Vector!(float, 3) vec3; /// ditto
alias Vector!(float, 4) vec4; /// ditto

alias Vector!(double, 2) vec2d; /// ditto
alias Vector!(double, 3) vec3d; /// ditto
alias Vector!(double, 4) vec4d; /// ditto

alias Vector!(int, 2) vec2i; /// ditto
alias Vector!(int, 3) vec3i; /// ditto
alias Vector!(int, 4) vec4i; /// ditto

enum isVector(T)		= is(T == Vector!Args,		Args...);



unittest
{
	assert(vec2.e1.vector == [1.0, 0.0]);
	assert(vec2.e2.vector == [0.0, 1.0]);
	
	assert(vec3.e1.vector == [1.0, 0.0, 0.0]);
	assert(vec3.e2.vector == [0.0, 1.0, 0.0]);
	assert(vec3.e3.vector == [0.0, 0.0, 1.0]);
	
	assert(vec4.e1.vector == [1.0, 0.0, 0.0, 0.0]);
	assert(vec4.e2.vector == [0.0, 1.0, 0.0, 0.0]);
	assert(vec4.e3.vector == [0.0, 0.0, 1.0, 0.0]);
	assert(vec4.e4.vector == [0.0, 0.0, 0.0, 1.0]);
}

unittest
{
	vec3 vec_clear;
	assert(vec_clear.isFinite);
	vec_clear.clear(1.0f);
	assert(vec_clear.isFinite);
	assert(vec_clear.vector == [1.0f, 1.0f, 1.0f]);
	assert(vec_clear.vector == vec3(1.0f).vector);
	vec_clear.clear(float.infinity);
	assert(!vec_clear.isFinite);
	vec_clear.clear(float.nan);
	assert(!vec_clear.isFinite);
	vec_clear.clear(1.0f);
	assert(vec_clear.isFinite);
	
	vec4 b = vec4(1.0f, vec_clear);
	assert(b.isFinite);
	assert(b.vector == [1.0f, 1.0f, 1.0f, 1.0f]);
	assert(b.vector == vec4(1.0f).vector);
	
	vec2 v2_1 = vec2(vec2(0.0f, 1.0f));
	assert(v2_1.vector == [0.0f, 1.0f]);
	
	vec2 v2_2 = vec2(1.0f, 1.0f);
	assert(v2_2.vector == [1.0f, 1.0f]);
	
	vec3 v3 = vec3(v2_1, 2.0f);
	assert(v3.vector == [0.0f, 1.0f, 2.0f]);
	
	vec4 v4_1 = vec4(1.0f, vec2(2.0f, 3.0f), 4.0f);
	assert(v4_1.vector == [1.0f, 2.0f, 3.0f, 4.0f]);
	assert(vec3(v4_1).vector == [1.0f, 2.0f, 3.0f]);
	assert(vec2(vec3(v4_1)).vector == [1.0f, 2.0f]);
	assert(vec2(vec3(v4_1)).vector == vec2(v4_1).vector);
	assert(v4_1.vector == vec4([1.0f, 2.0f, 3.0f, 4.0f]).vector);
	
	vec4 v4_2 = vec4(vec2(1.0f, 2.0f), vec2(3.0f, 4.0f));
	assert(v4_2.vector == [1.0f, 2.0f, 3.0f, 4.0f]);
	assert(vec3(v4_2).vector == [1.0f, 2.0f, 3.0f]);
	assert(vec2(vec3(v4_2)).vector == [1.0f, 2.0f]);
	assert(vec2(vec3(v4_2)).vector == vec2(v4_2).vector);
	assert(v4_2.vector == vec4([1.0f, 2.0f, 3.0f, 4.0f]).vector);
	
	float[2] f2 = [1.0f, 2.0f];
	float[3] f3 = [1.0f, 2.0f, 3.0f];
	float[4] f4 = [1.0f, 2.0f, 3.0f, 4.0f];
	assert(vec2(1.0f, 2.0f).vector == vec2(f2).vector);
	assert(vec3(1.0f, 2.0f, 3.0f).vector == vec3(f3).vector);
	assert(vec3(1.0f, 2.0f, 3.0f).vector == vec3(f2, 3.0f).vector);
	assert(vec4(1.0f, 2.0f, 3.0f, 4.0f).vector == vec4(f4).vector);
	assert(vec4(1.0f, 2.0f, 3.0f, 4.0f).vector == vec4(f3, 4.0f).vector);
	assert(vec4(1.0f, 2.0f, 3.0f, 4.0f).vector == vec4(f2, 3.0f, 4.0f).vector);
	// useful for: "vec4 v4 = […]" or "vec4 v4 = other_vector.rgba"
	
	assert(vec3(vec3i(1, 2, 3)) == vec3(1.0, 2.0, 3.0));
	assert(vec3d(vec3(1.0, 2.0, 3.0)) == vec3d(1.0, 2.0, 3.0));
}

unittest
{
	vec2 v2 = vec2(1.0f, 2.0f);
	assert(v2.x == 1.0f);
	assert(v2.y == 2.0f);
	v2.x = 3.0f;
	v2.x += 1;
	v2.x -= 1;
	assert(v2.vector == [3.0f, 2.0f]);
	v2.y = 4.0f;
	v2.y += 1;
	v2.y -= 1;
	assert(v2.vector == [3.0f, 4.0f]);
	assert((v2.x == 3.0f) && (v2.x == v2.u) && (v2.x == v2.s) && (v2.x == v2.r));
	assert(v2.y == 4.0f);
	assert((v2.y == 4.0f) && (v2.y == v2.v) && (v2.y == v2.t) && (v2.y == v2.g));
	v2.set(0.0f, 1.0f);
	assert(v2.vector == [0.0f, 1.0f]);
	v2 = vec2(3.0f, 4.0f);
	assert(v2.vector == [3.0f, 4.0f]);
	
	vec3 v3 = vec3(1.0f, 2.0f, 3.0f);
	assert(v3.x == 1.0f);
	assert(v3.y == 2.0f);
	assert(v3.z == 3.0f);
	v3.x = 3.0f;
	v3.x += 1;
	v3.x -= 1;
	assert(v3.vector == [3.0f, 2.0f, 3.0f]);
	v3.y = 4.0f;
	v3.y += 1;
	v3.y -= 1;
	assert(v3.vector == [3.0f, 4.0f, 3.0f]);
	v3.z = 5.0f;
	v3.z += 1;
	v3.z -= 1;
	assert(v3.vector == [3.0f, 4.0f, 5.0f]);
	assert((v3.x == 3.0f) && (v3.x == v3.s) && (v3.x == v3.r));
	assert((v3.y == 4.0f) && (v3.y == v3.t) && (v3.y == v3.g));
	assert((v3.z == 5.0f) && (v3.z == v3.p) && (v3.z == v3.b));
	v3.set(0.0f, 1.0f, 2.0f);
	assert(v3.vector == [0.0f, 1.0f, 2.0f]);
	v3 = vec3(3.0f, 4.0f, 5.0f);
	assert(v3.vector == [3.0f, 4.0f, 5.0f]);
	
	vec4 v4 = vec4(1.0f, 2.0f, vec2(3.0f, 4.0f));
	assert(v4.x == 1.0f);
	assert(v4.y == 2.0f);
	assert(v4.z == 3.0f);
	assert(v4.w == 4.0f);
	v4.x = 3.0f;
	v4.x += 1;
	v4.x -= 1;
	assert(v4.vector == [3.0f, 2.0f, 3.0f, 4.0f]);
	v4.y = 4.0f;
	v4.y += 1;
	v4.y -= 1;
	assert(v4.vector == [3.0f, 4.0f, 3.0f, 4.0f]);
	v4.z = 5.0f;
	v4.z += 1;
	v4.z -= 1;
	assert(v4.vector == [3.0f, 4.0f, 5.0f, 4.0f]);
	v4.w = 6.0f;
	v4.w += 1;
	v4.w -= 1;
	assert(v4.vector == [3.0f, 4.0f, 5.0f, 6.0f]);
	assert((v4.x == 3.0f) && (v4.x == v4.s) && (v4.x == v4.r));
	assert((v4.y == 4.0f) && (v4.y == v4.t) && (v4.y == v4.g));
	assert((v4.z == 5.0f) && (v4.z == v4.p) && (v4.z == v4.b));
	assert((v4.w == 6.0f) && (v4.w == v4.q) && (v4.w == v4.a));
	v4.set(0.0f, 1.0f, 2.0f, 3.0f);
	assert(v4.vector == [0.0f, 1.0f, 2.0f, 3.0f]);
	v4 = vec4(3.0f, 4.0f, 5.0f, 6.0f);
	assert(v4.vector == [3.0f, 4.0f, 5.0f, 6.0f]);
}

unittest
{
	vec2 v2 = vec2(1.0f, 2.0f);
	assert(v2.xytsy == [1.0f, 2.0f, 2.0f, 1.0f, 2.0f]);
	
	assert(vec3(1.0f, 2.0f, 3.0f).xybzyr == [1.0f, 2.0f, 3.0f, 3.0f, 2.0f, 1.0f]);
	assert(vec4(v2, 3.0f, 4.0f).xyzwrgbastpq == [1.0f, 2.0f, 3.0f, 4.0f,
		1.0f, 2.0f, 3.0f, 4.0f,
		1.0f, 2.0f, 3.0f, 4.0f]);
	assert(vec4(v2, 3.0f, 4.0f).wgyzax == [4.0f, 2.0f, 2.0f, 3.0f, 4.0f, 1.0f]);
	assert(vec4(v2.xyst).vector == [1.0f, 2.0f, 1.0f, 2.0f]);
}

unittest
{
	assert(vec2(1.0f, 1.0f) == -vec2(-1.0f, -1.0f));
	assert(vec2(-1.0f, 1.0f) == -vec2(1.0f, -1.0f));
	
	assert(-vec3(1.0f, 1.0f, 1.0f) == vec3(-1.0f, -1.0f, -1.0f));
	assert(-vec3(-1.0f, 1.0f, -1.0f) == vec3(1.0f, -1.0f, 1.0f));
	
	assert(vec4(1.0f, 1.0f, 1.0f, 1.0f) == -vec4(-1.0f, -1.0f, -1.0f, -1.0f));
	assert(vec4(-1.0f, 1.0f, -1.0f, 1.0f) == -vec4(1.0f, -1.0f, 1.0f, -1.0f));
}

unittest
{
	import kgl3n.matrix;

	vec2 v2 = vec2(1.0f, 3.0f);
	auto v2times2 = 2 * v2;
	assert((v2*2.5f).vector == [2.5f, 7.5f]);
	assert((v2+vec2(3.0f, 1.0f)).vector == [4.0f, 4.0f]);
	assert((v2-vec2(1.0f, 3.0f)).vector == [0.0f, 0.0f]);
	assert(v2.dot(vec2(2.0f, 2.0f)) == 8.0f);
	
	vec3 v3 = vec3(1.0f, 3.0f, 5.0f);
	assert((v3*2.5f).vector == [2.5f, 7.5f, 12.5f]);
	assert((v3+vec3(3.0f, 1.0f, -1.0f)).vector == [4.0f, 4.0f, 4.0f]);
	assert((v3-vec3(1.0f, 3.0f, 5.0f)).vector == [0.0f, 0.0f, 0.0f]);
	assert(v3.dot(vec3(2.0f, 2.0f, 2.0f)) == 18.0f);
	
	vec4 v4 = vec4(1.0f, 3.0f, 5.0f, 7.0f);
	assert((v4*2.5f).vector == [2.5f, 7.5f, 12.5f, 17.5]);
	assert((v4+vec4(3.0f, 1.0f, -1.0f, -3.0f)).vector == [4.0f, 4.0f, 4.0f, 4.0f]);
	assert((v4-vec4(1.0f, 3.0f, 5.0f, 7.0f)).vector == [0.0f, 0.0f, 0.0f, 0.0f]);
	assert(v4.dot(vec4(2.0f, 2.0f, 2.0f, 2.0f)) == 32.0f);
}

unittest
{
	import std.math : sqrt;
	import kgl3n.math : almostEqual;

	vec2 v2 = vec2(1.0f, 3.0f);
	v2 *= 2.5f;
	assert(v2.vector == [2.5f, 7.5f]);
	v2 -= vec2(2.5f, 7.5f);
	assert(v2.vector == [0.0f, 0.0f]);
	v2 += vec2(1.0f, 3.0f);
	assert(v2.vector == [1.0f, 3.0f]);
	assert(v2.magnitude == sqrt(10.0f));
	assert(v2.sqrMagnitude == 10.0f);
	assert(almostEqual(v2.normalized, vec2(1.0f/sqrt(10.0f), 3.0f/sqrt(10.0f))));
	
	vec3 v3 = vec3(1.0f, 3.0f, 5.0f);
	v3 *= 2.5f;
	assert(v3.vector == [2.5f, 7.5f, 12.5f]);
	v3 -= vec3(2.5f, 7.5f, 12.5f);
	assert(v3.vector == [0.0f, 0.0f, 0.0f]);
	v3 += vec3(1.0f, 3.0f, 5.0f);
	assert(v3.vector == [1.0f, 3.0f, 5.0f]);
	assert(v3.magnitude == sqrt(35.0f));
	assert(v3.sqrMagnitude == 35.0f);
	assert(almostEqual(v3.normalized, vec3(1.0f/sqrt(35.0f), 3.0f/sqrt(35.0f), 5.0f/sqrt(35.0f))));
	
	vec4 v4 = vec4(1.0f, 3.0f, 5.0f, 7.0f);
	v4 *= 2.5f;
	assert(v4.vector == [2.5f, 7.5f, 12.5f, 17.5]);
	v4 -= vec4(2.5f, 7.5f, 12.5f, 17.5f);
	assert(v4.vector == [0.0f, 0.0f, 0.0f, 0.0f]);
	v4 += vec4(1.0f, 3.0f, 5.0f, 7.0f);
	assert(v4.vector == [1.0f, 3.0f, 5.0f, 7.0f]);
	assert(v4.magnitude == sqrt(84.0f));
	assert(v4.sqrMagnitude == 84.0f);
	assert(almostEqual(v4.normalized, vec4(1.0f/sqrt(84.0f), 3.0f/sqrt(84.0f), 5.0f/sqrt(84.0f), 7.0f/sqrt(84.0f))));
}

unittest
{
	assert(vec2(1.0f, 2.0f) == vec2(1.0f, 2.0f));
	assert(vec2(1.0f, 2.0f) != vec2(1.0f, 1.0f));
	assert(vec2(1.0f, 2.0f) == vec2d(1.0, 2.0));
	assert(vec2(1.0f, 2.0f) != vec2d(1.0, 1.0));
	assert(vec2(1.0f, 2.0f) == vec2(1.0f, 2.0f).vector);
	assert(vec2(1.0f, 2.0f) != vec2(1.0f, 1.0f).vector);
	assert(vec2(1.0f, 2.0f) == vec2d(1.0, 2.0).vector);
	assert(vec2(1.0f, 2.0f) != vec2d(1.0, 1.0).vector);
	
	assert(vec3(1.0f, 2.0f, 3.0f) == vec3(1.0f, 2.0f, 3.0f));
	assert(vec3(1.0f, 2.0f, 3.0f) != vec3(1.0f, 2.0f, 2.0f));
	assert(vec3(1.0f, 2.0f, 3.0f) == vec3d(1.0, 2.0, 3.0));
	assert(vec3(1.0f, 2.0f, 3.0f) != vec3d(1.0, 2.0, 2.0));
	assert(vec3(1.0f, 2.0f, 3.0f) == vec3(1.0f, 2.0f, 3.0f).vector);
	assert(vec3(1.0f, 2.0f, 3.0f) != vec3(1.0f, 2.0f, 2.0f).vector);
	assert(vec3(1.0f, 2.0f, 3.0f) == vec3d(1.0, 2.0, 3.0).vector);
	assert(vec3(1.0f, 2.0f, 3.0f) != vec3d(1.0, 2.0, 2.0).vector);
	
	assert(vec4(1.0f, 2.0f, 3.0f, 4.0f) == vec4(1.0f, 2.0f, 3.0f, 4.0f));
	assert(vec4(1.0f, 2.0f, 3.0f, 4.0f) != vec4(1.0f, 2.0f, 3.0f, 3.0f));
	assert(vec4(1.0f, 2.0f, 3.0f, 4.0f) == vec4d(1.0, 2.0, 3.0, 4.0));
	assert(vec4(1.0f, 2.0f, 3.0f, 4.0f) != vec4d(1.0, 2.0, 3.0, 3.0));
	assert(vec4(1.0f, 2.0f, 3.0f, 4.0f) == vec4(1.0f, 2.0f, 3.0f, 4.0f).vector);
	assert(vec4(1.0f, 2.0f, 3.0f, 4.0f) != vec4(1.0f, 2.0f, 3.0f, 3.0f).vector);
	assert(vec4(1.0f, 2.0f, 3.0f, 4.0f) == vec4d(1.0, 2.0, 3.0, 4.0).vector);
	assert(vec4(1.0f, 2.0f, 3.0f, 4.0f) != vec4d(1.0, 2.0, 3.0, 3.0).vector);
	
	assert(!(vec4(float.nan)));
	if(vec4(1.0f)) { }
	else { assert(false); }
}

unittest
{
	vec3 v1 = vec3(1.0f, 2.0f, -3.0f);
	vec3 v2 = vec3(1.0f, 3.0f, 2.0f);
	
	assert(dot(v1, v2) == 1.0f);
	assert(dot(v1, v2) == dot(v2, v1));
	assert((v1 * v2) == (v1 * v2));
	
	assert(cross(v1, v2).vector == [13.0f, -5.0f, 1.0f]);
	assert(cross(v2, v1).vector == [-13.0f, 5.0f, -1.0f]);
	
	assert(distance(vec2(0.0f, 0.0f), vec2(0.0f, 10.0f)) == 10.0);
}