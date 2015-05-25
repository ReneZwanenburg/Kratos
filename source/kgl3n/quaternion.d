module kgl3n.quaternion;

import kgl3n.vector;
import kgl3n.matrix;

import vibe.data.serialization : optional;

/// Base template for all quaternion-types.
/// Params:
///  type = all values get stored as this type
struct Quaternion(type)
{
	@optional:

	alias qt = type; /// Holds the internal type of the quaternion.
	alias vt = Vector!(qt, 4);

	vt quaternion = vt(0, 0, 0, 1);

	@property
	{
		ref inout(qt) x() inout { return quaternion.x; }
		ref inout(qt) y() inout { return quaternion.y; }
		ref inout(qt) z() inout { return quaternion.z; }
		ref inout(qt) w() inout { return quaternion.w; }
		qt magnitude() const { return quaternion.magnitude; }
		qt sqrMagnitude() const { return quaternion.sqrMagnitude; }
	}

	
	/// Returns a pointer to the quaternion in memory, it starts with the w coordinate.
	@property auto ptr()
	{
		return quaternion.ptr;
	}
	
	/// Returns the current vector formatted as string, useful for printing the quaternion.
	@property string toString()
	{
		return quaternion.toString();
	}

	auto toRepresentation()
	{
		return quaternion;
	}

	static Quaternion fromRepresentation(typeof(quaternion) quaternion)
	{
		return Quaternion(quaternion);
	}
	
	/// Returns true if all values are not nan and finite, otherwise false.
	@property bool isFinite() const
	{
		return quaternion.isFinite;
	}

	
	/// Inverts the quaternion.
	void invert()
	{
		quaternion.xyz = -quaternion.xyz;
	}
	
	/// Returns an inverted copy of the current quaternion.
	@property Quaternion inverted() const
	{
		Quaternion ret = this;
		ret.invert;
		return ret;
	}
	
	/// Creates a quaternion from a 3x3 matrix.
	/// Params:
	///  matrix = 3x3 matrix (rotation)
	/// Returns: A quaternion representing the rotation (3x3 matrix)
	static Quaternion fromMatrix(Matrix!(qt, 3) mat)
	{
		import std.math : sqrt;
		Quaternion ret;

		auto trace = mat.trace;
		
		if(trace > 0)
		{
			real s = 0.5 / sqrt(trace + 1.0f);
			
			ret.w = 0.25 / s;
			ret.x = (mat[2][1] - mat[1][2]) * s;
			ret.y = (mat[0][2] - mat[2][0]) * s;
			ret.z = (mat[1][0] - mat[0][1]) * s;
		}
		else if((mat[0][0] > mat[1][1]) && (mat[0][0] > mat[2][2]))
		{
			real s = 2.0 * sqrt(1.0 + mat[0][0] - mat[1][1] - mat[2][2]);
			
			ret.w = (mat[2][1] - mat[1][2]) / s;
			ret.x = 0.25f * s;
			ret.y = (mat[0][1] + mat[1][0]) / s;
			ret.z = (mat[0][2] + mat[2][0]) / s;
		}
		else if(mat[1][1] > mat[2][2])
		{
			real s = 2.0 * sqrt(1 + mat[1][1] - mat[0][0] - mat[2][2]);
			
			ret.w = (mat[0][2] - mat[2][0]) / s;
			ret.x = (mat[0][1] + mat[1][0]) / s;
			ret.y = 0.25f * s;
			ret.z = (mat[1][2] + mat[2][1]) / s;
		}
		else
		{
			real s = 2.0 * sqrt(1 + mat[2][2] - mat[0][0] - mat[1][1]);
			
			ret.w = (mat[1][0] - mat[0][1]) / s;
			ret.x = (mat[0][2] + mat[2][0]) / s;
			ret.y = (mat[1][2] + mat[2][1]) / s;
			ret.z = 0.25f * s;
		}
		
		return ret;
	}
	
	/// Returns the quaternion as matrix.
	/// Params:
	///  rows = number of rows of the resulting matrix (min 3)
	///  cols = number of columns of the resulting matrix (min 3)
	Matrix!(qt, dimension) toMatrix(size_t dimension)() const
		if(dimension >= 3)
	{
		Matrix!(qt, dimension) ret;

		qt xx = x * x;
		qt xy = x * y;
		qt xz = x * z;
		qt xw = x * w;
		qt yy = y * y;
		qt yz = y * z;
		qt yw = y * w;
		qt zz = z * z;
		qt zw = z * w;
		
		ret.matrix[0][0..3][] = [1 - 2 * (yy + zz), 2 * (xy - zw), 2 * (xz + yw)];
		ret.matrix[1][0..3][] = [2 * (xy + zw), 1 - 2 * (xx + zz), 2 * (yz - xw)];
		ret.matrix[2][0..3][] = [2 * (xz - yw), 2 * (yz + xw), 1 - 2 * (xx + yy)];
		
		return ret;
	}
	
	/// Normalizes the current quaternion.
	void normalize()
	{
		quaternion.normalize;
	}
	
	/// Returns a normalized copy of the current quaternion.
	Quaternion normalized() const
	{
		return Quaternion(quaternion.normalized);
	}
	
	/// Returns the yaw.
	@property real yaw() const
	{
		import std.math : atan2;
		return atan2(2 * (w*y + x*z), w*w - x*x - y*y + z*z);
	}
	
	/// Returns the pitch.
	@property real pitch() const
	{
		import std.math : asin;
		return asin(2 * (w*x - y*z));
	}
	
	/// Returns the roll.
	@property real roll() const
	{
		import std.math : atan2;
		return atan2(2 * (w*z + x*y), w^^2 - x^^2 + y^^2 - z^^2);
	}
	
	/// Returns a quaternion with applied rotation around the x-axis.
	static Quaternion xRotation(real alpha)
	{
		Quaternion ret;
		
		alpha /= 2;
		ret.w = cos(alpha);
		ret.x = sin(alpha);
		ret.y = 0;
		ret.z = 0;
		
		return ret;
	}
	
	/// Returns a quaternion with applied rotation around the y-axis.
	static Quaternion yRotation(real alpha)
	{
		Quaternion ret;
		
		alpha /= 2;
		ret.w = cos(alpha);
		ret.x = 0;
		ret.y = sin(alpha);
		ret.z = 0;
		
		return ret;
	}
	
	/// Returns a quaternion with applied rotation around the z-axis.
	static Quaternion zRotation(real alpha)
	{
		Quaternion ret;
		
		alpha /= 2;
		ret.w = cos(alpha);
		ret.x = 0;
		ret.y = 0;
		ret.z = sin(alpha);
		
		return ret;
	}
	
	/// Returns a quaternion with applied rotation around an axis.
	static Quaternion axisRotation(real alpha, Vector!(qt, 3) axis)
	{
		if(alpha == 0)
		{
			return Quaternion();
		}
		Quaternion ret;
		
		alpha /= 2;
		qt sinaqt = sin(alpha);
		
		ret.w = cos(alpha);
		ret.x = axis.x * sinaqt;
		ret.y = axis.y * sinaqt;
		ret.z = axis.z * sinaqt;
		
		return ret;
	}
	
	/// Creates a quaternion from an euler rotation.
	static Quaternion eulerRotation(vec3 ypr)
	{
		Quaternion ret;

		real c1 = cos(ypr.x / 2);
		real s1 = sin(ypr.x / 2);
		real c2 = cos(ypr.z / 2);
		real s2 = sin(ypr.z / 2);
		real c3 = cos(ypr.y / 2);
		real s3 = sin(ypr.y / 2);

		ret.w = c1 * c2 * c3 - s1 * s2 * s3;
		ret.x = s1 * s2 * c3 + c1 * c2 * s3;
		ret.y = s1 * c2 * c3 + c1 * s2 * s3;
		ret.z = c1 * s2 * c3 - s1 * c2 * s3;
		
		return ret;
	}
	
	/// Rotates the current quaternion around the x-axis and returns $(I this).
	Quaternion rotateX(real alpha)
	{
		this = xRotation(alpha) * this;
		return this;
	}
	
	/// Rotates the current quaternion around the y-axis and returns $(I this).
	Quaternion rotateY(real alpha)
	{
		this = yRotation(alpha) * this;
		return this;
	}
	
	/// Rotates the current quaternion around the z-axis and returns $(I this).
	Quaternion rotateZ(real alpha)
	{
		this = zRotation(alpha) * this;
		return this;
	}
	
	/// Rotates the current quaternion around an axis and returns $(I this).
	Quaternion rotateAxis(real alpha, Vector!(qt, 3) axis) {
		this = axisRotation(alpha, axis) * this;
		return this;
	}
	
	/// Applies an euler rotation to the current quaternion and returns $(I this).
	Quaternion rotateEuler(vec3 ypr)
	{
		this = eulerRotation(ypr) * this;
		return this;
	}
	
	Quaternion opBinary(string op : "*")(Quaternion inp) const
	{
		Quaternion ret;
		
		ret.w = -x * inp.x - y * inp.y - z * inp.z + w * inp.w;
		ret.x = x * inp.w + y * inp.z - z * inp.y + w * inp.x;
		ret.y = -x * inp.z + y * inp.w + z * inp.x + w * inp.y;
		ret.z = x * inp.y - y * inp.x + z * inp.w + w * inp.z;
		
		return ret;
	}
	
	auto opBinaryRight(string op, T)(T inp) const if(!isQuaternion!T)
	{
		return this.opBinary!(op)(inp);
	}
	
	Quaternion opBinary(string op)(Quaternion inp) const
		if((op == "+") || (op == "-"))
	{
		mixin("return Quaternion(quaternion"~op~"inp.quaternion);");
	}
	
	Vector!(qt, 3) opBinary(string op : "*")(Vector!(qt, 3) inp) const
	{
		Vector!(qt, 3) ret;
		
		qt ww = w * w;
		qt w2 = w * 2;
		qt wx2 = w2 * x;
		qt wy2 = w2 * y;
		qt wz2 = w2 * z;
		qt xx = x * x;
		qt x2 = x * 2;
		qt xy2 = x2 * y;
		qt xz2 = x2 * z;
		qt yy = y * y;
		qt yz2 = 2 * y * z;
		qt zz = z * z;
		
		ret.vector =  [ww * inp.x + wy2 * inp.z - wz2 * inp.y + xx * inp.x +
			xy2 * inp.y + xz2 * inp.z - zz * inp.x - yy * inp.x,
			xy2 * inp.x + yy * inp.y + yz2 * inp.z + wz2 * inp.x -
			zz * inp.y + ww * inp.y - wx2 * inp.z - xx * inp.y,
			xz2 * inp.x + yz2 * inp.y + zz * inp.z - wy2 * inp.x -
			yy * inp.z + wx2 * inp.y - xx * inp.z + ww * inp.z];
		
		return ret;
	}
	
	Quaternion opBinary(string op : "*")(qt inp) const
	{
		return Quaternion(quaternion * inp);
	}
	
	void opOpAssign(string op : "*")(Quaternion inp)
	{
		qt w2 = -x * inp.x - y * inp.y - z * inp.z + w * inp.w;
		qt x2 = x * inp.w + y * inp.z - z * inp.y + w * inp.x;
		qt y2 = -x * inp.z + y * inp.w + z * inp.x + w * inp.y;
		qt z2 = x * inp.y - y * inp.x + z * inp.w + w * inp.z;
		w = w2; x = x2; y = y2; z = z2;
	}
	
	void opOpAssign(string op)(Quaternion inp)
		if((op == "+") || (op == "-"))
	{
		mixin("w = w" ~ op ~ "inp.w;");
		mixin("x = x" ~ op ~ "inp.x;");
		mixin("y = y" ~ op ~ "inp.y;");
		mixin("z = z" ~ op ~ "inp.z;");
	}
	
	void opOpAssign(string op : "*")(qt inp)
	{
		quaternion[0] *= inp;
		quaternion[1] *= inp;
		quaternion[2] *= inp;
		quaternion[3] *= inp;
	}
	
	int opCmp(ref const Quaternion qua) const
	{
		foreach(i, a; quaternion)
		{
			if(a < qua.quaternion[i])
			{
				return -1;
			}
			else if(a > qua.quaternion[i])
			{
				return 1;
			}
		}
		
		// Quaternions are the same
		return 0;
	}
	
	bool opEquals(const Quaternion qu) const
	{
		return quaternion == qu.quaternion;
	}
	
	bool opCast(T : bool)() const
	{
		return isFinite;
	}
	
}

/// Pre-defined quaternion of type float.
alias Quaternion!(float) quat;

enum isQuaternion(T)	= is(T == Quaternion!Args,	Args...);


unittest
{
	quat q1 = quat(vec4(0.0f, 0.0f, 0.0f, 1.0f));
	assert(q1.quaternion.vector == [0.0f, 0.0f, 0.0f, 1.0f]);
	
	assert(q1.isFinite);
	q1.x = float.infinity;
	assert(!q1.isFinite);
	q1.x = float.nan;
	assert(!q1.isFinite);
	q1.x = 0.0f;
	assert(q1.isFinite);
}

unittest
{
	quat q1 = quat(vec4(1.0f, 1.0f, 1.0f, 1.0f));
	
	assert(q1.magnitude == 2.0f);
	assert(q1.sqrMagnitude == 4.0f);
	assert(q1.magnitude == quat(vec4(0.0f, 0.0f, 2.0f, 0.0f)).magnitude);
	
	quat q2 = quat();
	assert(q2.quaternion.vector == [0.0f, 0.0f, 0.0f, 1.0f]);
	assert(q2.x == 0.0f);
	assert(q2.y == 0.0f);
	assert(q2.z == 0.0f);
	assert(q2.w == 1.0f);
	
	assert(q1.inverted.quaternion.vector == [-1.0f, -1.0f, -1.0f, 1.0f]);
	q1.invert();
	assert(q1.quaternion.vector == [-1.0f, -1.0f, -1.0f, 1.0f]);

	q1 = quat();
	assert(q1.quaternion == q2.quaternion);
}

unittest
{
	import kgl3n.math : almostEqual;

	quat q1 = quat(vec4(1.0f, 2.0f, 3.0f, 4.0));
	
	assert(q1.toMatrix!(3).matrix == [vec3(-25.0f, -20.0f, 22.0f), vec3(28.0f, -19.0f, 4.0f), vec3(-10.0f, 20.0f, -9.0f)]);
	assert(q1.toMatrix!(4).matrix == [
		vec4(-25.0f, -20.0f, 22.0f, 0.0f),
		vec4(28.0f, -19.0f, 4.0f, 0.0f),
		vec4(-10.0f, 20.0f, -9.0f, 0.0f),
		vec4(0.0f, 0.0f, 0.0f, 1.0f)]);
	assert(quat().toMatrix!(3).matrix == Matrix!(float, 3)().matrix);
	assert(q1.quaternion == quat.fromMatrix(q1.toMatrix!(3)).quaternion);
	
	assert(quat(vec4(0.0f, 0.0f, 0.0f, 1.0f)).quaternion == quat.fromMatrix(mat3()).quaternion);
	
	quat q2 = quat.fromMatrix(mat3(1.0f, 3.0f, 2.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f));
	assert(q2.x == 0.0f);
	assert(almostEqual(q2.y, 0.7071067f));
	assert(almostEqual(q2.z, -1.060660));
	assert(almostEqual(q2.w, 0.7071067f));
}

unittest
{
	import kgl3n.math : almostEqual;
	import std.math : isNaN;

	quat q1 = quat();
	assert(q1.pitch == 0.0f);
	assert(q1.yaw == 0.0f);
	assert(q1.roll == 0.0f);
	
	quat q2 = quat(vec4(1.0f, 1.0f, 1.0f, 1.0f));
	assert(almostEqual(q2.yaw, q2.roll));
	assert(almostEqual(q2.yaw, 1.570796f));
	assert(q2.pitch == 0.0f);
	
	quat q3 = quat(vec4(1.9f, 2.1f, 1.3f, 0.1f));
	assert(almostEqual(q3.yaw, 2.4382f));
	assert(isNaN(q3.pitch));
	assert(almostEqual(q3.roll, 1.67719f));
}

unittest
{
	import kgl3n.math : almostEqual;

	quat q1 = quat(vec4(2.0f, 3.0f, 4.0f, 1.0f));
	quat q2 = quat(vec4(2.0f, 3.0f, 4.0f, 1.0f));
	
	q1.normalize();
	assert(q1.quaternion == q2.normalized.quaternion);
	//assert(q1.quaternion == q1.normalized.quaternion);
	assert(almostEqual(q1.magnitude, 1.0));
}

unittest
{
	assert(quat.xRotation(PI).quaternion[0..3] == [1.0f, 0.0f, 0.0f]);
	assert(quat.yRotation(PI).quaternion[0..3] == [0.0f, 1.0f, 0.0f]);
	assert(quat.zRotation(PI).quaternion[0..3] == [0.0f, 0.0f, 1.0f]);
	assert((quat.xRotation(PI).w == quat.yRotation(PI).w) && (quat.yRotation(PI).w == quat.zRotation(PI).w));

	assert(quat.xRotation(PI).quaternion == quat().rotateX(PI).quaternion);
	assert(quat.yRotation(PI).quaternion == quat().rotateY(PI).quaternion);
	assert(quat.zRotation(PI).quaternion == quat().rotateZ(PI).quaternion);
	
	assert(quat.axisRotation(PI, vec3(1.0f, 1.0f, 1.0f)).quaternion[0..3] == [1.0f, 1.0f, 1.0f]);
	assert(quat.axisRotation(PI, vec3(1.0f, 1.0f, 1.0f)).w == quat.xRotation(PI).w);
	assert(quat.axisRotation(PI, vec3(1.0f, 1.0f, 1.0f)).quaternion ==
	       quat().rotateAxis(PI, vec3(1.0f, 1.0f, 1.0f)).quaternion);
	
	quat q1 = quat.eulerRotation(PI, PI, PI);
	assert((q1.x > -1e-16) && (q1.x < 1e-16));
	assert((q1.y > -1e-16) && (q1.y < 1e-16));
	assert((q1.z > -1e-16) && (q1.z < 1e-16));
	assert(q1.w == -1.0f);
	assert(quat.eulerRotation(PI, PI, PI).quaternion == quat().rotateEuler(PI, PI, PI).quaternion);
}

unittest
{
	import kgl3n.math : almostEqual;

	quat q1 = quat();
	quat q2 = quat(vec4(0.0f, 1.0f, 2.0f, 3.0f));
	quat q3 = quat(vec4(0.1f, 1.2f, 2.3f, 3.4f));
	
	assert((q1 * q1).quaternion == q1.quaternion);
	assert((q1 * q2).quaternion == q2.quaternion);
	assert((q2 * q1).quaternion == q2.quaternion);
	quat q4 = q3 * q2;
	assert((q2 * q3).quaternion != q4.quaternion);
	q3 *= q2;
	assert(q4.quaternion == q3.quaternion);
	assert(almostEqual(q4.x, 0.4f));
	assert(almostEqual(q4.y, 6.8f));
	assert(almostEqual(q4.z, 13.8f));
	assert(almostEqual(q4.w, 4.4f));
	
	quat q5 = quat(vec4(2.0f, 3.0f, 4.0f, 1.0f));
	quat q6 = quat(vec4(1.0f, 6.0f, 2.0f, 3.0f));

	assert((q5 - q6).quaternion == [1.0f, -3.0f, 2.0f, -2.0f]);
	assert((q5 + q6).quaternion == [3.0f, 9.0f, 6.0f, 4.0f]);
	assert((q6 - q5).quaternion == [-1.0f, 3.0f, -2.0f, 2.0f]);
	assert((q6 + q5).quaternion == [3.0f, 9.0f, 6.0f, 4.0f]);
	q5 += q6;
	assert(q5.quaternion == [3.0f, 9.0f, 6.0f, 4.0f]);
	q6 -= q6;
	assert(q6.quaternion == [0.0f, 0.0f, 0.0f, 0.0f]);
	
	quat q7 = quat(vec4(2.0f, 2.0f, 2.0f, 2.0f));
	assert((q7 * 2).quaternion == [4.0f, 4.0f, 4.0f, 4.0f]);
	assert((2 * q7).quaternion == (q7 * 2).quaternion);
	q7 *= 2;
	assert(q7.quaternion == [4.0f, 4.0f, 4.0f, 4.0f]);
	
	vec3 v1 = vec3(1.0f, 2.0f, 3.0f);
	assert((q1 * v1).vector == v1.vector);
	assert((v1 * q1).vector == (q1 * v1).vector);
	assert((q2 * v1).vector == [-2.0f, 36.0f, 38.0f]);
}

unittest
{
	assert(quat(vec4(1.0f, 2.0f, 3.0f, 4.0f)) == quat(vec4(1.0f, 2.0f, 3.0f, 4.0f)));
	assert(quat(vec4(1.0f, 2.0f, 3.0f, 4.0f)) != quat(vec4(1.0f, 2.0f, 3.0f, 3.0f)));
	
	assert(!(quat(vec4(float.nan, float.nan, float.nan, float.nan))));
	if(quat(vec4(1.0f, 1.0f, 1.0f, 1.0f))) { }
	else { assert(false); }
}