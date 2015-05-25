module kgl3n.matrix;

import kgl3n.vector;
import kgl3n.util;
import std.traits : isFloatingPoint, isIntegral;
import std.algorithm : reduce, min;
import std.math : sin, cos, tan, PI;

import vibe.data.serialization : optional;

version(NoReciprocalMul)
{
	private enum ReciprocalMul = false;
}
else
{
	private enum ReciprocalMul = true;
}

/// Base template for all matrix-types.
/// Params:
///  type = all values get stored as this type
///  rows_ = rows of the matrix
///  cols_ = columns of the matrix
/// Examples:
/// ---
/// alias Matrix!(float, 4, 4) mat4;
/// alias Matrix!(double, 3, 4) mat34d;
/// alias Matrix!(real, 2, 2) mat2r;
/// ---
struct Matrix(type, size_t dimension_)
	if(dimension_ > 0)
{
	@optional:

	enum dimension = dimension_; /// Holds the number of rows and columns;
	enum elementCount = dimension * dimension;

	alias mt = type; /// Holds the internal type of the matrix;
	alias vt = Vector!(mt, dimension);

	// Transform vector type. Used to define transforms so a 4x4 matrix still takes vec3 translate/scale/... parameters
	private alias tvt = Vector!(mt, min(dimension, 3));
	
	/// Holds the matrix $(RED row-major) in memory.
	vt[dimension] matrix = identityVectors;
	alias matrix this;
	
	/// Returns the pointer to the stored values as OpenGL requires it.
	/// Note this will return a pointer to a $(RED row-major) matrix,
	/// $(RED this means you've to set the transpose argument to GL_TRUE when passing it to OpenGL).
	/// Examples:
	/// ---
	/// // 3rd argument = GL_TRUE
	/// glUniformMatrix4fv(programs.main.model, 1, GL_TRUE, mat4.translation(-0.5f, -0.5f, 1.0f).value_ptr);
	/// ---
	@property auto ptr()
	{
		return matrix[0].ptr;
	}
	
	/// Returns the current matrix formatted as flat string.
	@property string toString()
	{
		import std.string : format;
		return format("%s", matrix);
	}
	
	/// Returns the current matrix as pretty formatted string.
	@property string toPrettyString() {
		import std.string : format, rightJustify, join;
		string fmtr = "%s";
		
		size_t rjust = max(format(fmtr, reduce!(max)(matrix[])).length,
		                   format(fmtr, reduce!(min)(matrix[])).length) - 1;
		
		string[] outer_parts;
		foreach(row; matrix) {
			string[] inner_parts;
			foreach(mt col; row) {
				inner_parts ~= rightJustify(format(fmtr, col), rjust);
			}
			outer_parts ~= " [" ~ join(inner_parts, ", ") ~ "]";
		}
		
		return "[" ~ join(outer_parts, "\n")[1..$] ~ "]";
	}

	auto toRepresentation()
	{
		return matrix;
	}

	static Matrix fromRepresentation(typeof(matrix) matrix)
	{
		Matrix retVal;
		retVal.matrix = matrix;
		return retVal;
	}
	
	@safe pure nothrow:
	enum isCompatibleMatrix(T) = is(T == Matrix!(mt, D), D...);
	enum isCompatibleVector(T) = is(T == Vector!(mt, D), D...);
	
	private void construct(int i, T, Tail...)(T head, Tail tail)
	{
		static if(i >= elementCount)
		{
			static assert(false, "Too many arguments passed to constructor");
		}
		else static if(is(T : mt))
		{
			matrix[i / dimension][i % dimension] = head;
			construct!(i + 1)(tail);
		}
		else static if(is(T == Vector!(mt, dimension)))
		{
			static if(i % dimension == 0)
			{
				matrix[i / dimension] = head;
				construct!(i + T.dimension)(tail);
			}
			else
			{
				static assert(false, "Can't convert Vector into the matrix. Maybe it doesn't align to the columns correctly or dimension doesn't fit");
			}
		}
		else
		{
			static assert(false, "Matrix constructor argument must be of type " ~ mt.stringof ~ " or Vector, not " ~ T.stringof);
		}
	}
	
	private void construct(int i)()
	{ // terminate
		static assert(i == elementCount, "Not enough arguments passed to constructor");
	}
	
	/// Constructs the matrix:
	/// If a single value is passed, the matrix will be cleared with this value (each column in each row will contain this value).
	/// If a matrix with more rows and columns is passed, the matrix will be the upper left nxm matrix.
	/// If a matrix with less rows and columns is passed, the passed matrix will be stored in the upper left of an identity matrix.
	/// It's also allowed to pass vectors and scalars at a time, but the vectors dimension must match the number of columns and align correctly.
	/// Examples:
	/// ---
	/// mat2 m2 = mat2(0.0f); // mat2 m2 = mat2(0.0f, 0.0f, 0.0f, 0.0f);
	/// mat3 m3 = mat3(m2); // mat3 m3 = mat3(0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 0.0f, 1.0f);
	/// mat3 m3_2 = mat3(vec3(1.0f, 2.0f, 3.0f), 4.0f, 5.0f, 6.0f, vec3(7.0f, 8.0f, 9.0f));
	/// mat4 m4 = mat4.identity; // just an identity matrix
	/// mat3 m3_3 = mat3(m4); // mat3 m3_3 = mat3.identity
	/// ---
	this(Args...)(Args args)
	{
		construct!(0)(args);
	}
	
	/// ditto
	this(T)(T mat)
		if(isMatrix!T)
	{
		foreach(r; TupleRange!(0, min(dimension, T.dimension)))
		{
			matrix[r] = vt(mat[r]);
		}
	}

	/// ditto
	this()(mt value)
	{
		clear(value);
	}
	
	/// Returns true if all values are not nan and finite, otherwise false.
	@property bool isFinite() const
	{
		static if(isIntegral!type)
		{
			return true;
		}
		else
		{
			import std.algorithm : all;
			return matrix[].all!(a => a.isFinite);
		}
	}
	
	/// Sets all values of the matrix to value (each column in each row will contain this value).
	void clear(mt value)
	{
		foreach(r; TupleRange!(0, dimension))
		{
			matrix[r] = vt(value);
		}
	}

	const(vt) col(size_t index) const
	in
	{
		assert(index < dimension);
	}
	body
	{
		vt vec;
		
		foreach(i; TupleRange!(0, dimension))
		{
			vec[i] = matrix[i][index];
		}
		
		return vec;
	}

	/// Transposes the current matrix;
	ref Matrix transpose()
	{
		//TODO improve perf
		this = transposed;
		return this;
	}
	
	/// Returns a transposed copy of the matrix.
	@property Matrix transposed() const
	{
		Matrix ret;

		foreach(c; TupleRange!(0, dimension))
		{
			ret[c] = col(c);
		}
		
		return ret;
	}
	
	// transposed already tested in last unittest


	@property mt trace() const
	{
		mt ret = 0;
		foreach(i; TupleRange!(0, dimension))
		{
			ret += matrix[i][i];
		}
		return ret;
	}

	static Matrix scaling(tvt v)
	{
		Matrix ret;
		foreach(i; TupleRange!(0, tvt.dimension))
		{
			ret[i][i] = v[i];
		}
		return ret;
	}

	static Matrix translation(tvt v)
	{
		Matrix ret;

		foreach(i; TupleRange!(0, tvt.dimension))
		{
			ret.matrix[i][dimension-1] = v[i];
		}
		
		return ret;
	}

	ref Matrix translate(tvt v)
	{
		//TODO improve perf
		this = translation(v) * this;
		return this;
	}
	
	vt translation() const
	{
		return col(dimension-1);
	}
	
	static if(dimension == 2)
	{
		@property mt det() const
		{
			return (matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0]);
		}

		private void invert(ref Matrix mat) const
		{
			static if(isFloatingPoint!mt && ReciprocalMul)
			{
				mt d = 1 / det;

				mat = Matrix
				(
					matrix[1][1]*d, -matrix[0][1]*d,
					-matrix[1][0]*d, matrix[0][0]*d
				);
			}
			else
			{
				mt d = det;

				mat = Matrix
				(
					matrix[1][1]/d, -matrix[0][1]/d,
					-matrix[1][0]/d, matrix[0][0]/d
				);
			}
		}
	}
	else static if(dimension == 3)
	{
		@property mt det() const
		{
			return (matrix[0][0] * matrix[1][1] * matrix[2][2]
			+ matrix[0][1] * matrix[1][2] * matrix[2][0]
			+ matrix[0][2] * matrix[1][0] * matrix[2][1]
			- matrix[0][2] * matrix[1][1] * matrix[2][0]
			- matrix[0][1] * matrix[1][0] * matrix[2][2]
			- matrix[0][0] * matrix[1][2] * matrix[2][1]);
		}
		
		private void invert(ref Matrix mat) const
		{
			static if(isFloatingPoint!mt && ReciprocalMul)
			{
				mt d = 1 / det;
				enum op = "*";
			}
			else
			{
				mt d = det;
				enum op = "/";
			}
			
			mixin(`
            mat = Matrix((matrix[1][1] * matrix[2][2] - matrix[1][2] * matrix[2][1])`~op~`d,
                         (matrix[0][2] * matrix[2][1] - matrix[0][1] * matrix[2][2])`~op~`d,
                         (matrix[0][1] * matrix[1][2] - matrix[0][2] * matrix[1][1])`~op~`d,
                         (matrix[1][2] * matrix[2][0] - matrix[1][0] * matrix[2][2])`~op~`d,
                         (matrix[0][0] * matrix[2][2] - matrix[0][2] * matrix[2][0])`~op~`d,
                         (matrix[0][2] * matrix[1][0] - matrix[0][0] * matrix[1][2])`~op~`d,
                         (matrix[1][0] * matrix[2][1] - matrix[1][1] * matrix[2][0])`~op~`d,
                         (matrix[0][1] * matrix[2][0] - matrix[0][0] * matrix[2][1])`~op~`d,
                         (matrix[0][0] * matrix[1][1] - matrix[0][1] * matrix[1][0])`~op~`d);
            `);
		}
	}
	else static if(dimension == 4)
	{
		/// Returns the determinant of the current matrix (2x2, 3x3 and 4x4 matrices).
		@property mt det() const
		{
			return (matrix[0][3] * matrix[1][2] * matrix[2][1] * matrix[3][0] - matrix[0][2] * matrix[1][3] * matrix[2][1] * matrix[3][0]
			- matrix[0][3] * matrix[1][1] * matrix[2][2] * matrix[3][0] + matrix[0][1] * matrix[1][3] * matrix[2][2] * matrix[3][0]
			+ matrix[0][2] * matrix[1][1] * matrix[2][3] * matrix[3][0] - matrix[0][1] * matrix[1][2] * matrix[2][3] * matrix[3][0]
			- matrix[0][3] * matrix[1][2] * matrix[2][0] * matrix[3][1] + matrix[0][2] * matrix[1][3] * matrix[2][0] * matrix[3][1]
			+ matrix[0][3] * matrix[1][0] * matrix[2][2] * matrix[3][1] - matrix[0][0] * matrix[1][3] * matrix[2][2] * matrix[3][1]
			- matrix[0][2] * matrix[1][0] * matrix[2][3] * matrix[3][1] + matrix[0][0] * matrix[1][2] * matrix[2][3] * matrix[3][1]
			+ matrix[0][3] * matrix[1][1] * matrix[2][0] * matrix[3][2] - matrix[0][1] * matrix[1][3] * matrix[2][0] * matrix[3][2]
			- matrix[0][3] * matrix[1][0] * matrix[2][1] * matrix[3][2] + matrix[0][0] * matrix[1][3] * matrix[2][1] * matrix[3][2]
			+ matrix[0][1] * matrix[1][0] * matrix[2][3] * matrix[3][2] - matrix[0][0] * matrix[1][1] * matrix[2][3] * matrix[3][2]
			- matrix[0][2] * matrix[1][1] * matrix[2][0] * matrix[3][3] + matrix[0][1] * matrix[1][2] * matrix[2][0] * matrix[3][3]
			+ matrix[0][2] * matrix[1][0] * matrix[2][1] * matrix[3][3] - matrix[0][0] * matrix[1][2] * matrix[2][1] * matrix[3][3]
			- matrix[0][1] * matrix[1][0] * matrix[2][2] * matrix[3][3] + matrix[0][0] * matrix[1][1] * matrix[2][2] * matrix[3][3]);
		}

		private void invert(ref Matrix mat) const
		{
			static if(isFloatingPoint!mt && ReciprocalMul)
			{
				mt d = 1 / det;
				enum op = "*";
			}
			else
			{
				mt d = det;
				enum op = "/";
			}
			
			mixin(`
            mat.matrix = Matrix(
                          (matrix[1][1] * matrix[2][2] * matrix[3][3] + matrix[1][2] * matrix[2][3] * matrix[3][1] + matrix[1][3] * matrix[2][1] * matrix[3][2]
                         -matrix[1][1] * matrix[2][3] * matrix[3][2] - matrix[1][2] * matrix[2][1] * matrix[3][3] - matrix[1][3] * matrix[2][2] * matrix[3][1])`~op~`d,
                          (matrix[0][1] * matrix[2][3] * matrix[3][2] + matrix[0][2] * matrix[2][1] * matrix[3][3] + matrix[0][3] * matrix[2][2] * matrix[3][1]
                         -matrix[0][1] * matrix[2][2] * matrix[3][3] - matrix[0][2] * matrix[2][3] * matrix[3][1] - matrix[0][3] * matrix[2][1] * matrix[3][2])`~op~`d,
                          (matrix[0][1] * matrix[1][2] * matrix[3][3] + matrix[0][2] * matrix[1][3] * matrix[3][1] + matrix[0][3] * matrix[1][1] * matrix[3][2]
                         -matrix[0][1] * matrix[1][3] * matrix[3][2] - matrix[0][2] * matrix[1][1] * matrix[3][3] - matrix[0][3] * matrix[1][2] * matrix[3][1])`~op~`d,
                          (matrix[0][1] * matrix[1][3] * matrix[2][2] + matrix[0][2] * matrix[1][1] * matrix[2][3] + matrix[0][3] * matrix[1][2] * matrix[2][1]
                         -matrix[0][1] * matrix[1][2] * matrix[2][3] - matrix[0][2] * matrix[1][3] * matrix[2][1] - matrix[0][3] * matrix[1][1] * matrix[2][2])`~op~`d,
                          (matrix[1][0] * matrix[2][3] * matrix[3][2] + matrix[1][2] * matrix[2][0] * matrix[3][3] + matrix[1][3] * matrix[2][2] * matrix[3][0]
                         -matrix[1][0] * matrix[2][2] * matrix[3][3] - matrix[1][2] * matrix[2][3] * matrix[3][0] - matrix[1][3] * matrix[2][0] * matrix[3][2])`~op~`d,
                          (matrix[0][0] * matrix[2][2] * matrix[3][3] + matrix[0][2] * matrix[2][3] * matrix[3][0] + matrix[0][3] * matrix[2][0] * matrix[3][2]
                         -matrix[0][0] * matrix[2][3] * matrix[3][2] - matrix[0][2] * matrix[2][0] * matrix[3][3] - matrix[0][3] * matrix[2][2] * matrix[3][0])`~op~`d,
                          (matrix[0][0] * matrix[1][3] * matrix[3][2] + matrix[0][2] * matrix[1][0] * matrix[3][3] + matrix[0][3] * matrix[1][2] * matrix[3][0]
                         -matrix[0][0] * matrix[1][2] * matrix[3][3] - matrix[0][2] * matrix[1][3] * matrix[3][0] - matrix[0][3] * matrix[1][0] * matrix[3][2])`~op~`d,
                          (matrix[0][0] * matrix[1][2] * matrix[2][3] + matrix[0][2] * matrix[1][3] * matrix[2][0] + matrix[0][3] * matrix[1][0] * matrix[2][2]
                         -matrix[0][0] * matrix[1][3] * matrix[2][2] - matrix[0][2] * matrix[1][0] * matrix[2][3] - matrix[0][3] * matrix[1][2] * matrix[2][0])`~op~`d,
                          (matrix[1][0] * matrix[2][1] * matrix[3][3] + matrix[1][1] * matrix[2][3] * matrix[3][0] + matrix[1][3] * matrix[2][0] * matrix[3][1]
                         -matrix[1][0] * matrix[2][3] * matrix[3][1] - matrix[1][1] * matrix[2][0] * matrix[3][3] - matrix[1][3] * matrix[2][1] * matrix[3][0])`~op~`d,
                          (matrix[0][0] * matrix[2][3] * matrix[3][1] + matrix[0][1] * matrix[2][0] * matrix[3][3] + matrix[0][3] * matrix[2][1] * matrix[3][0]
                         -matrix[0][0] * matrix[2][1] * matrix[3][3] - matrix[0][1] * matrix[2][3] * matrix[3][0] - matrix[0][3] * matrix[2][0] * matrix[3][1])`~op~`d,
                          (matrix[0][0] * matrix[1][1] * matrix[3][3] + matrix[0][1] * matrix[1][3] * matrix[3][0] + matrix[0][3] * matrix[1][0] * matrix[3][1]
                         -matrix[0][0] * matrix[1][3] * matrix[3][1] - matrix[0][1] * matrix[1][0] * matrix[3][3] - matrix[0][3] * matrix[1][1] * matrix[3][0])`~op~`d,
                          (matrix[0][0] * matrix[1][3] * matrix[2][1] + matrix[0][1] * matrix[1][0] * matrix[2][3] + matrix[0][3] * matrix[1][1] * matrix[2][0]
                         -matrix[0][0] * matrix[1][1] * matrix[2][3] - matrix[0][1] * matrix[1][3] * matrix[2][0] - matrix[0][3] * matrix[1][0] * matrix[2][1])`~op~`d,
                          (matrix[1][0] * matrix[2][2] * matrix[3][1] + matrix[1][1] * matrix[2][0] * matrix[3][2] + matrix[1][2] * matrix[2][1] * matrix[3][0]
                         -matrix[1][0] * matrix[2][1] * matrix[3][2] - matrix[1][1] * matrix[2][2] * matrix[3][0] - matrix[1][2] * matrix[2][0] * matrix[3][1])`~op~`d,
                          (matrix[0][0] * matrix[2][1] * matrix[3][2] + matrix[0][1] * matrix[2][2] * matrix[3][0] + matrix[0][2] * matrix[2][0] * matrix[3][1]
                         -matrix[0][0] * matrix[2][2] * matrix[3][1] - matrix[0][1] * matrix[2][0] * matrix[3][2] - matrix[0][2] * matrix[2][1] * matrix[3][0])`~op~`d,
                          (matrix[0][0] * matrix[1][2] * matrix[3][1] + matrix[0][1] * matrix[1][0] * matrix[3][2] + matrix[0][2] * matrix[1][1] * matrix[3][0]
                         -matrix[0][0] * matrix[1][1] * matrix[3][2] - matrix[0][1] * matrix[1][2] * matrix[3][0] - matrix[0][2] * matrix[1][0] * matrix[3][1])`~op~`d,
                          (matrix[0][0] * matrix[1][1] * matrix[2][2] + matrix[0][1] * matrix[1][2] * matrix[2][0] + matrix[0][2] * matrix[1][0] * matrix[2][1]
                         -matrix[0][0] * matrix[1][2] * matrix[2][1] - matrix[0][1] * matrix[1][0] * matrix[2][2] - matrix[0][2] * matrix[1][1] * matrix[2][0])`~op~`d);
            `);
		}
	}

	
	static if(dimension >= 3 && isFloatingPoint!mt)
	{

		
		ref Matrix scale(tvt v)
		{
			foreach(i; TupleRange!(0, tvt.dimension))
			{
				matrix[i] *= v[i];
			}
			return this;
		}
		
		vt scale() const
		{
			vt retVal;
			
			foreach(i; TupleRange!(0, dimension))
			{
				retVal[i] = matrix[i].xyz.magnitude;
			}
			
			return retVal;
		}

		/// Returns an identity matrix with an applied rotateAxis around an arbitrary axis (nxn matrices, n >= 3).
		static Matrix rotation(real alpha, tvt axis)
		{
			Matrix mult;
			
			real cosa = cos(alpha);
			real sina = sin(alpha);

			auto temp = (1 - cosa)*axis;
			
			mult.matrix[0].xyz = tvt(
				cosa + temp.x * axis.x,
				temp.x * axis.y + sina * axis.z,
				temp.x * axis.z - sina * axis.y
			);

			mult.matrix[1].xyz = tvt(
				temp.y * axis.x - sina * axis.z,
				cosa + temp.y * axis.y,
				temp.y * axis.z + sina * axis.x
			);

			mult.matrix[2].xyz = tvt(
				temp.z * axis.x + sina * axis.y,
				temp.z * axis.y - sina * axis.x,
				cosa + temp.z * axis.z
			);
			
			return mult;
		}

		static Matrix rotationN(real alpha, tvt axis)
		{
			return rotation(alpha, axis.normalized);
		}
		
		/// Returns an identity matrix with an applied rotation around the x-axis (nxn matrices, n >= 3).
		static Matrix xRotation(real alpha)
		{
			Matrix mult;
			
			mt cosamt = cos(alpha);
			mt sinamt = sin(alpha);

			mult.matrix[1].yz = Vector!(mt, 2)(cosamt, -sinamt);
			mult.matrix[2].yz = Vector!(mt, 2)(sinamt, cosamt);
			
			return mult;
		}
		
		/// Returns an identity matrix with an applied rotation around the y-axis (nxn matrices, n >= 3).
		static Matrix yRotation(real alpha)
		{
			Matrix mult;
			
			mt cosamt = cos(alpha);
			mt sinamt = sin(alpha);
			
			mult.matrix[0].xz = Vector!(mt, 2)(cosamt, sinamt);
			mult.matrix[2].xz = Vector!(mt, 2)(-sinamt, cosamt);
			
			return mult;
		}
		
		/// Returns an identity matrix with an applied rotation around the z-axis (nxn matrices, n >= 3).
		static Matrix zRotation(real alpha)
		{
			Matrix mult;
			
			mt cosamt = cos(alpha);
			mt sinamt = sin(alpha);
			
			mult.matrix[0].xy = Vector!(mt, 2)(cosamt, -sinamt);
			mult.matrix[1].xy = Vector!(mt, 2)(sinamt, cosamt);
			
			return mult;
		}

		ref Matrix rotate(real alpha, tvt axis)
		{
			this = rotation(alpha, axis) * this;
			return this;
		}

		ref Matrix rotateN(real alpha, tvt axis)
		{
			rotate(alpha, axis.normalized);
			return this;
		}
		
		/// Rotates the current matrix around the x-axis and returns $(I this) (nxn matrices, n >= 3).
		ref Matrix rotateX(real alpha)
		{
			this = xRotation(alpha) * this;
			return this;
		}

		/// Rotates the current matrix around the y-axis and returns $(I this) (nxn matrices, n >= 3).
		ref Matrix rotateY(real alpha)
		{
			this = yRotation(alpha) * this;
			return this;
		}

		/// Rotates the current matrix around the z-axis and returns $(I this) (nxn matrices, n >= 3).
		ref Matrix rotateZ(real alpha)
		{
			this = zRotation(alpha) * this;
			return this;
		}
	}
	
	static if((dimension >= 2) && (dimension <= 4))
	{
		/// Returns an inverted copy of the current matrix (nxn matrices, 2 >= n <= 4).
		@property Matrix inverse() const
		{
			Matrix mat;
			invert(mat);
			return mat;
		}
		
		/// Inverts the current matrix (nxn matrices, 2 >= n <= 4).
		ref Matrix invert()
		{
			// workaround Issue #11238
			// uses a temporary instead of invert(this)
			Matrix temp;
			invert(temp);
			this = temp;
			return this;
		}
	}
	
	private void mms(mt inp, ref Matrix mat) const
	{ // mat * scalar
		foreach(i; TupleRange!(0, dimension))
		{
			mat.matrix[i] = matrix[i] * inp;
		}
	}
	
	private void masm(string op)(Matrix inp, ref Matrix mat) const
	{ // mat + or - mat
		foreach(i; TupleRange!(0, dimension))
		{
			mat.matrix[i] = inp.matrix[i].opBinary!op(matrix[i]);
		}
	}

	Matrix opBinary(string op : "*")(Matrix inp) const
	{
		Matrix ret;
		
		foreach(r; TupleRange!(0, dimension))
		{
			foreach(c; TupleRange!(0, dimension))
			{
				ret.matrix[r][c] = dot(matrix[r], inp.col(c));
			}
		}
		
		return ret;
	}

	vt opBinary(string op : "*")(vt inp) const
	{
		vt ret;

		foreach(i; TupleRange!(0, dimension))
		{
			ret[i] = dot(matrix[i], inp);
		}
		
		return ret;
	}
	
	Matrix opBinary(string op : "*")(mt inp) const
	{
		Matrix ret;
		mms(inp, ret);
		return ret;
	}
	
	Matrix opBinaryRight(string op : "*")(mt inp) const
	{
		return this.opBinary!(op)(inp);
	}
	
	Matrix opBinary(string op)(Matrix inp) const if((op == "+") || (op == "-"))
	{
		Matrix ret;
		masm!(op)(inp, ret);
		return ret;
	}
	
	void opOpAssign(string op : "*")(mt inp)
	{
		mms(inp, this);
	}
	
	void opOpAssign(string op)(Matrix inp) if((op == "+") || (op == "-"))
	{
		masm!(op)(inp, this);
	}
	
	bool opCast(T : bool)() const
	{
		return isFinite;
	}
	
	private static @property vt[dimension] identityVectors()
	{
		vt[dimension] vectors;
		foreach(i; TupleRange!(0, dimension))
		{
			vectors[i][i] = 1;
		}
		return vectors;
	}
	
}

/// Pre-defined matrix types, the first number represents the number of rows
/// and the second the number of columns, if there's just one it's a nxn matrix.
/// All of these matrices are floating-point matrices.
alias Matrix!(float, 2) mat2;
alias Matrix!(float, 3) mat3;
alias Matrix!(float, 4) mat4;

unittest
{
	Matrix!(float,  1) A = 1;
	Matrix!(double, 1) B = 1;
	Matrix!(real,   1) C = 1;
	Matrix!(int,    1) D = 1;
	Matrix!(float,  5) E = 1;
	Matrix!(double, 5) F = 1;
	Matrix!(real,   5) G = 1;
	Matrix!(int,    5) H = 1;
}

enum isMatrix(T)		= is(T == Matrix!Args,		Args...);

private T[6] cperspective(T)(T width, T height, T fov, T near, T far)
if(isFloatingPoint!T)
in
{
	assert(height != 0);
}
body
{
	T aspect = width/height;
	T top = near * tan(fov*(PI/360.0));
	T bottom = -top;
	T right = top * aspect;
	T left = -right;
	
	return [left, right, bottom, top, near, far];
}
	
/// Returns a perspective matrix (4x4 and floating-point matrices only).
mat4 perspectiveProjection(float width, float height, float fov, float near, float far)
{
	auto cdata = cperspective(width, height, fov, near, far);
	return perspectiveProjection(cdata[0], cdata[1], cdata[2], cdata[3], cdata[4], cdata[5]);
}

/// ditto
mat4 perspectiveProjection(float left, float right, float bottom, float top, float near, float far)
in
{
	assert(right-left != 0);
	assert(top-bottom != 0);
	assert(far-near != 0);
}
body
{
	typeof(return) ret;
	alias vt = Vector!(ret.mt, 2);
	
	ret.matrix[0].xz = vt((2*near)/(right-left)		, (right+left)/(right-left));
	ret.matrix[1].yz = vt((2*near)/(top-bottom)		, (top+bottom)/(top-bottom));
	ret.matrix[2].zw = vt(-(far+near)/(far-near)	, -(2*far*near)/(far-near));
	ret.matrix[3].zw = vt(-1						, 0);
	
	return ret;
}

/// Returns an inverse perspective matrix (4x4 and floating-point matrices only).
mat4 perspectiveProjectionInverse(float width, float height, float fov, float near, float far)
{
	auto cdata = cperspective(width, height, fov, near, far);
	return perspectiveProjectionInverse(cdata[0], cdata[1], cdata[2], cdata[3], cdata[4], cdata[5]);
}

/// ditto
mat4 perspectiveProjectionInverse(float left, float right, float bottom, float top, float near, float far)
in
{
	assert(near != 0);
	assert(far != 0);
}
body
{
	typeof(return) ret;
	alias vt = Vector!(ret.mt, 2);
	
	ret.matrix[0].xw = vt((right-left)/(2*near)		, (right+left)/(2*near));
	ret.matrix[1].yw = vt((top-bottom)/(2*near)		, (top+bottom)/(2*near));
	ret.matrix[2].zw = vt(0							, -1);
	ret.matrix[3].zw = vt(-(far-near)/(2*far*near)	, (far+near)/(2*far*near));
	
	return ret;
}

// (2) and (3) say this one is correct
/// Returns an orthographic matrix (4x4 and floating-point matrices only).
mat4 orthographicProjection(float left, float right, float bottom, float top, float near, float far)
in
{
	assert(right-left != 0);
	assert(top-bottom != 0);
	assert(far-near != 0);
}
body
{
	typeof(return) ret;
	alias vt = Vector!(ret.mt, 2);
	
	ret.matrix[0].xw = vt(2/(right-left)	, -(right+left)/(right-left));
	ret.matrix[1].yw = vt(2/(top-bottom)	, -(top+bottom)/(top-bottom));
	ret.matrix[2].zw = vt(-2/(far-near)		, -(far+near)/(far-near));
	
	return ret;
}

// (1) and (2) say this one is correct
/// Returns an inverse ortographic matrix (4x4 and floating-point matrices only).
mat4 orthographicProjectionInverse(float left, float right, float bottom, float top, float near, float far)
{
	typeof(return) ret;
	alias vt = Vector!(ret.mt, 2);
	
	ret.matrix[0].xw = vt((right-left)/2	, (right+left)/2);
	ret.matrix[1].yw = vt((top-bottom)/2	, (top+bottom)/2);
	ret.matrix[2].zw = vt((far-near)/-2		, (far+near)/2);
	
	return ret;
}

/// Returns a look at matrix (4x4 and floating-point matrices only).
Matrix!(T.vt, 4) lookAtMatrix(T = vec3)(T eye, T target, T up = T.e2)
if(isVector!T)
{
	T look_dir = (target - eye).normalized;
	T up_dir = up.normalized;

	T right_dir = cross(look_dir, up_dir).normalized;
	T perp_up_dir = cross(right_dir, look_dir);
	
	typeof(return) ret;
	ret.matrix[0].xyz = right_dir;
	ret.matrix[1].xyz = perp_up_dir;
	ret.matrix[2].xyz = -look_dir;
	
	ret.matrix[0][3] = -dot(eye, right_dir);
	ret.matrix[1][3] = -dot(eye, perp_up_dir);
	ret.matrix[2][3] = dot(eye, look_dir);
	
	return ret;
}

unittest
{
	mat2 m2 = mat2(0.0f, 1.0f, 2.0f, 3.0f);
	assert(m2[0][0] == 0.0f);
	assert(m2[0][1] == 1.0f);
	assert(m2[1][0] == 2.0f);
	assert(m2[1][1] == 3.0f);
	m2[0..1] = vec2(2.0f, 2.0f);
	assert(m2 == [vec2(2.0f, 2.0f), vec2(2.0f, 3.0f)]);
	
	mat3 m3 = mat3(0.0f, 0.1f, 0.2f, 1.0f, 1.1f, 1.2f, 2.0f, 2.1f, 2.2f);
	assert(m3[0][1] == 0.1f);
	assert(m3[2][0] == 2.0f);
	assert(m3[1][2] == 1.2f);
	m3.matrix[0] = vec3(0.0f);
	assert(m3 == [
		vec3(0.0f, 0.0f, 0.0f),
		vec3(1.0f, 1.1f, 1.2f),
		vec3(2.0f, 2.1f, 2.2f)]);
	
	mat4 m4 = mat4(0.0f, 0.1f, 0.2f, 0.3f,
	               1.0f, 1.1f, 1.2f, 1.3f,
	               2.0f, 2.1f, 2.2f, 2.3f,
	               3.0f, 3.1f, 3.2f, 3.3f);
	assert(m4[0][3] == 0.3f);
	assert(m4[1][1] == 1.1f);
	assert(m4[2][0] == 2.0f);
	assert(m4[3][2] == 3.2f);
	m4[2].yz = vec2(1.0f, 2.0f);
	assert(m4 == [
		vec4(0.0f, 0.1f, 0.2f, 0.3f),
		vec4(1.0f, 1.1f, 1.2f, 1.3f),
		vec4(2.0f, 1.0f, 2.0f, 2.3f),
		vec4(3.0f, 3.1f, 3.2f, 3.3f)]);
}

unittest
{
	mat2 m2 = mat2(1.0f, 1.0f, vec2(2.0f, 2.0f));
	assert(m2.matrix == [vec2(1.0f, 1.0f), vec2(2.0f, 2.0f)]);
	m2.clear(3.0f);
	assert(m2.matrix == [vec2(3.0f, 3.0f), vec2(3.0f, 3.0f)]);
	assert(m2.isFinite);
	m2.clear(float.nan);
	assert(!m2.isFinite);
	m2.clear(float.infinity);
	assert(!m2.isFinite);
	m2.clear(0.0f);
	assert(m2.isFinite);
	
	mat3 m3 = mat3(1.0f);
	assert(m3.matrix == [
		vec3(1.0f, 1.0f, 1.0f),
		vec3(1.0f, 1.0f, 1.0f),
		vec3(1.0f, 1.0f, 1.0f)]);
	
	mat4 m4 = mat4(
		vec4(1.0f, 1.0f, 1.0f, 1.0f),
	    2.0f, 2.0f, 2.0f, 2.0f,
	    3.0f, 3.0f, 3.0f, 3.0f,
	    vec4(4.0f, 4.0f, 4.0f, 4.0f));
	assert(m4.matrix == [
		vec4(1.0f, 1.0f, 1.0f, 1.0f),
		vec4(2.0f, 2.0f, 2.0f, 2.0f),
		vec4(3.0f, 3.0f, 3.0f, 3.0f),
		vec4(4.0f, 4.0f, 4.0f, 4.0f)]);
	assert(mat3(m4).matrix == [
		vec3(1.0f, 1.0f, 1.0f),
		vec3(2.0f, 2.0f, 2.0f),
		vec3(3.0f, 3.0f, 3.0f)]);
	assert(mat2(mat3(m4)).matrix == [vec2(1.0f, 1.0f), vec2(2.0f, 2.0f)]);
	assert(mat2(m4).matrix == mat2(mat3(m4)).matrix);
	assert(mat4(mat3(m4)).matrix == [
		vec4(1.0f, 1.0f, 1.0f, 0.0f),
		vec4(2.0f, 2.0f, 2.0f, 0.0f),
		vec4(3.0f, 3.0f, 3.0f, 0.0f),
		vec4(0.0f, 0.0f, 0.0f, 1.0f)]);
}

unittest
{
	mat2 m2 = mat2(1.0f);
	m2.transpose();
	assert(m2.matrix == mat2(1.0f).matrix);
	m2 = mat2();
	assert(m2.matrix == [vec2(1.0f, 0.0f), vec2(0.0f, 1.0f)]);
	m2.transpose();
	assert(m2.matrix == [vec2(1.0f, 0.0f), vec2(0.0f, 1.0f)]);
	assert(m2.matrix == mat2().matrix);
	
	mat3 m3 = mat3(1.1f, 1.2f, 1.3f,
	               2.1f, 2.2f, 2.3f,
	               3.1f, 3.2f, 3.3f);
	m3.transpose();
	assert(m3.matrix == [
		vec3(1.1f, 2.1f, 3.1f),
		vec3(1.2f, 2.2f, 3.2f),
		vec3(1.3f, 2.3f, 3.3f)]);
	
	mat4 m4 = mat4(2.0f);
	m4.transpose();
	assert(m4.matrix == mat4(2.0f).matrix);
}

unittest
{
	assert(mat2.scaling(vec2(3, 3)).matrix == mat2().scale(vec2(3, 3)).matrix);
	assert(mat2.scaling(vec2(3, 3)).matrix == [vec2(3.0f, 0.0f), vec2(0.0f, 3.0f)]);
}

unittest
{
	mat3 m3 = mat3(1.0f);
	assert(m3.translation(vec3(1.0f, 2.0f, 3.0f)).matrix == mat3.translation(vec3(1.0f, 2.0f, 3.0f)).matrix);
	assert(mat3.translation(vec3(1.0f, 2.0f, 3.0f)).matrix == [
		vec3(1.0f, 0.0f, 1.0f),
		vec3(0.0f, 1.0f, 2.0f),
		vec3(0.0f, 0.0f, 3.0f)]);
	assert(mat3().translate(vec3(0.0f, 1.0f, 2.0f)).matrix == mat3.translation(vec3(0.0f, 1.0f, 2.0f)).matrix);
	
	assert(m3.scaling(vec3(0.0f, 1.0f, 2.0f)).matrix == mat3.scaling(vec3(0.0f, 1.0f, 2.0f)).matrix);
	assert(mat3.scaling(vec3(0.0f, 1.0f, 2.0f)).matrix == [
		vec3(0.0f, 0.0f, 0.0f),
		vec3(0.0f, 1.0f, 0.0f),
		vec3(0.0f, 0.0f, 2.0f)]);
	assert(mat3().scale(vec3(0.0f, 1.0f, 2.0f)).matrix == mat3.scaling(vec3(0.0f, 1.0f, 2.0f)).matrix);
	
	// same tests for 4x4
	
	mat4 m4 = mat4(1.0f);
	assert(m4.translation(vec3(1.0f, 2.0f, 3.0f)).matrix == mat4.translation(vec3(1.0f, 2.0f, 3.0f)).matrix);
	assert(mat4.translation(vec3(1.0f, 2.0f, 3.0f)).matrix == [
		vec4(1.0f, 0.0f, 0.0f, 1.0f),
		vec4(0.0f, 1.0f, 0.0f, 2.0f),
		vec4(0.0f, 0.0f, 1.0f, 3.0f),
		vec4(0.0f, 0.0f, 0.0f, 1.0f)]);
	assert(mat4().translate(vec3(0.0f, 1.0f, 2.0f)).matrix == mat4.translation(vec3(0.0f, 1.0f, 2.0f)).matrix);
	
	assert(m4.scaling(vec3(0.0f, 1.0f, 2.0f)).matrix == mat4.scaling(vec3(0.0f, 1.0f, 2.0f)).matrix);
	assert(mat4.scaling(vec3(0.0f, 1.0f, 2.0f)).matrix == [
		vec4(0.0f, 0.0f, 0.0f, 0.0f),
		vec4(0.0f, 1.0f, 0.0f, 0.0f),
		vec4(0.0f, 0.0f, 2.0f, 0.0f),
		vec4(0.0f, 0.0f, 0.0f, 1.0f)]);
	assert(mat4().scale(vec3(0.0f, 1.0f, 2.0f)).matrix == mat4.scaling(vec3(0.0f, 1.0f, 2.0f)).matrix);
}

unittest
{
	import kgl3n.math : almostEqual;

	assert(mat4.xRotation(0).almostEqual(mat4(
		vec4(1.0f, 0.0f, 0.0f, 0.0f),
		vec4(0.0f, 1.0f, 0.0f, 0.0f),
		vec4(0.0f, 0.0f, 1.0f, 0.0f),
		vec4(0.0f, 0.0f, 0.0f, 1.0f))));
	assert(mat4.yRotation(0).almostEqual(mat4(
		vec4(1.0f, 0.0f, 0.0f, 0.0f),
		vec4(0.0f, 1.0f, 0.0f, 0.0f),
		vec4(0.0f, 0.0f, 1.0f, 0.0f),
		vec4(0.0f, 0.0f, 0.0f, 1.0f))));
	assert(mat4.zRotation(0).almostEqual(mat4(
		vec4(1.0f, -0.0f, 0.0f, 0.0f),
		vec4(0.0f, 1.0f, 0.0f, 0.0f),
		vec4(0.0f, 0.0f, 1.0f, 0.0f),
		vec4(0.0f, 0.0f, 0.0f, 1.0f))));
	mat4 xro = mat4();
	xro.rotateX(0);
	assert(mat4.xRotation(0).almostEqual(xro));
	assert(xro.almostEqual(mat4().rotateX(0)));
	assert(xro.almostEqual(mat4.rotation(0, vec3(1.0f, 0.0f, 0.0f))));
	mat4 yro = mat4();
	yro.rotateY(0);
	assert(mat4.yRotation(0).almostEqual(yro));
	assert(yro.almostEqual(mat4().rotateY(0)));
	assert(yro.almostEqual(mat4.rotation(0, vec3(0.0f, 1.0f, 0.0f))));
	mat4 zro = mat4();
	xro.rotateZ(0);
	assert(mat4.zRotation(0).almostEqual(zro));
	assert(zro.almostEqual(mat4().rotateZ(0)));
	assert(zro.almostEqual(mat4.rotation(0, vec3(0.0f, 0.0f, 1.0f))));
}

unittest
{
	mat2 m2 = mat2(1.0f, 2.0f, vec2(3.0f, 4.0f));
	assert(m2.det == -2.0f);
	assert(m2.inverse.matrix == [
		vec2(-2.0f, 1.0f),
		vec2(1.5f, -0.5f)]);
	
	mat3 m3 = mat3(1.0f, -2.0f, 3.0f,
	               7.0f, -1.0f, 0.0f,
	               3.0f, 2.0f, -4.0f);
	assert(m3.det == -1.0f);
	assert(m3.inverse.matrix == [
		vec3(-4.0f, 2.0f, -3.0f),
		vec3(-28.0f, 13.0f, -21.0f),
		vec3(-17.0f, 8.0f, -13.0f)]);
	
	mat4 m4 = mat4(1.0f, 2.0f, 3.0f, 4.0f,
	               -2.0f, 1.0f, 5.0f, -2.0f,
	               2.0f, -1.0f, 7.0f, 1.0f,
	               3.0f, -3.0f, 2.0f, 0.0f);
	assert(m4.det == -8.0f);
	assert(m4.inverse.matrix == [
		vec4(6.875f, 7.875f, -11.75f, 11.125f),
		vec4(6.625f, 7.625f, -11.25f, 10.375f),
		vec4(-0.375f, -0.375f, 0.75f, -0.625f),
		vec4(-4.5f, -5.5f, 8.0f, -7.5f)]);
}

unittest
{
	mat2 m2 = mat2(1.0f, 2.0f, 3.0f, 4.0f);
	vec2 v2 = vec2(2.0f, 2.0f);
	assert((m2*2).matrix == [vec2(2.0f, 4.0f), vec2(6.0f, 8.0f)]);
	assert((2*m2).matrix == (m2*2).matrix);
	m2 *= 2;
	assert(m2.matrix == [vec2(2.0f, 4.0f), vec2(6.0f, 8.0f)]);
	assert((m2*v2).vector == [12.0f, 28.0f]);
	assert((m2*m2).matrix == [vec2(28.0f, 40.0f), vec2(60.0f, 88.0f)]);
	assert((m2-m2).matrix == [vec2(0.0f, 0.0f), vec2(0.0f, 0.0f)]);
	assert((m2+m2).matrix == [vec2(4.0f, 8.0f), vec2(12.0f, 16.0f)]);
	m2 += m2;
	assert(m2.matrix == [vec2(4.0f, 8.0f), vec2(12.0f, 16.0f)]);
	m2 -= m2;
	assert(m2.matrix == [vec2(0.0f, 0.0f), vec2(0.0f, 0.0f)]);
	
	mat3 m3 = mat3(1.0f, 2.0f, 3.0f, 4.0f, 5.0f, 6.0f, 7.0f, 8.0f, 9.0f);
	vec3 v3 = vec3(2.0f, 2.0f, 2.0f);
	assert((m3*2).matrix == [vec3(2.0f, 4.0f, 6.0f), vec3(8.0f, 10.0f, 12.0f), vec3(14.0f, 16.0f, 18.0f)]);
	assert((2*m3).matrix == (m3*2).matrix);
	m3 *= 2;
	assert(m3.matrix == [vec3(2.0f, 4.0f, 6.0f), vec3(8.0f, 10.0f, 12.0f), vec3(14.0f, 16.0f, 18.0f)]);
	assert((m3*v3).vector == [24.0f, 60.0f, 96.0f]);
	assert((m3*m3).matrix == [vec3(120.0f, 144.0f, 168.0f), vec3(264.0f, 324.0f, 384.0f), vec3(408.0f, 504.0f, 600.0f)]);
	assert((m3-m3).matrix == [vec3(0.0f, 0.0f, 0.0f), vec3(0.0f, 0.0f, 0.0f), vec3(0.0f, 0.0f, 0.0f)]);
	assert((m3+m3).matrix == [vec3(4.0f, 8.0f, 12.0f), vec3(16.0f, 20.0f, 24.0f), vec3(28.0f, 32.0f, 36.0f)]);
	m3 += m3;
	assert(m3.matrix == [vec3(4.0f, 8.0f, 12.0f), vec3(16.0f, 20.0f, 24.0f), vec3(28.0f, 32.0f, 36.0f)]);
	m3 -= m3;
	assert(m3.matrix == [vec3(0.0f, 0.0f, 0.0f), vec3(0.0f, 0.0f, 0.0f), vec3(0.0f, 0.0f, 0.0f)]);
	
	//TODO: tests for mat4, mat34
}

unittest
{
	assert(mat2(1.0f, 2.0f, 1.0f, 1.0f) == mat2(1.0f, 2.0f, 1.0f, 1.0f));
	assert(mat2(1.0f, 2.0f, 1.0f, 1.0f) != mat2(1.0f, 1.0f, 1.0f, 1.0f));
	
	assert(mat3(1.0f) == mat3(1.0f));
	assert(mat3(1.0f) != mat3(2.0f));
	
	assert(mat4(1.0f) == mat4(1.0f));
	assert(mat4(1.0f) != mat4(2.0f));
	
	assert(!(mat4(float.nan)));
	if(mat4(1.0f)) { }
	else { assert(false); }
}

unittest
{
	import kgl3n.math : almostEqual;

	float[6] cp = cperspective(600f, 900f, 60f, 1f, 100f);
	assert(cp[4] == 1.0f);
	assert(cp[5] == 100.0f);
	assert(cp[0] == -cp[1]);
	assert((cp[0] < -0.38489f) && (cp[0] > -0.38491f));
	assert(cp[2] == -cp[3]);
	assert((cp[2] < -0.577349f) && (cp[2] > -0.577351f));
	
	assert(perspectiveProjection(600f, 900f, 60.0f, 1.0f, 100.0f) == perspectiveProjection(cp[0], cp[1], cp[2], cp[3], cp[4], cp[5]));
	vec4[4] m4p = perspectiveProjection(600f, 900f, 60.0f, 1.0f, 100.0f).matrix;
	assert((m4p[0][0] < 2.598077f) && (m4p[0][0] > 2.598075f));
	assert(m4p[0][2] == 0.0f);
	assert((m4p[1][1] < 1.732052) && (m4p[1][1] > 1.732050));
	assert(m4p[1][2] == 0.0f);
	assert((m4p[2][2] < -1.020201) && (m4p[2][2] > -1.020203));
	assert((m4p[2][3] < -2.020201) && (m4p[2][3] > -2.020203));
	assert((m4p[3][2] < -0.9f) && (m4p[3][2] > -1.1f));
	
	vec4[4] m4pi = perspectiveProjectionInverse(600f, 900f, 60.0f, 1.0f, 100.0f).matrix;
	assert((m4pi[0][0] < 0.384901) && (m4pi[0][0] > 0.384899));
	assert(m4pi[0][3] == 0.0f);
	assert((m4pi[1][1] < 0.577351) && (m4pi[1][1] > 0.577349));
	assert(m4pi[1][3] == 0.0f);
	assert(m4pi[2][3] == -1.0f);
	assert((m4pi[3][2] < -0.494999) && (m4pi[3][2] > -0.495001));
	assert((m4pi[3][3] < 0.505001) && (m4pi[3][3] > 0.504999));

	// maybe the next tests should be improved
	mat4 m4o = orthographicProjection(-1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f);
	assert(m4o.almostEqual(mat4(
		vec4(1.0f, 0.0f, 0.0f, 0.0f),
		vec4(0.0f, 1.0f, 0.0f, 0.0f),
		vec4(0.0f, 0.0f, -1.0f, 0.0f),
		vec4(0.0f, 0.0f, 0.0f, 1.0f))));

	mat4 m4oi = orthographicProjectionInverse(-1.0f, 1.0f, -1.0f, 1.0f, -1.0f, 1.0f);
	assert(m4oi.almostEqual(mat4(
		vec4(1.0f, 0.0f, 0.0f, 0.0f),
		vec4(0.0f, 1.0f, 0.0f, 0.0f),
		vec4(0.0f, 0.0f, -1.0f, 0.0f),
		vec4(0.0f, 0.0f, 0.0f, 1.0f))));
	
	//TODO: lookAt tests
}