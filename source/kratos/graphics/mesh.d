﻿module kratos.graphics.mesh;

import kratos.graphics.bo;

Mesh emptyMesh()
{
	static Mesh emptyMesh = void;
	static bool initialized = false;

	if(!initialized)
	{
		import gl3n.linalg;
		static struct S{ vec3 _; }
		S[] sArr;
		uint[] iArr;

		emptyMesh = Mesh(IBO(iArr), VBO(sArr));
		initialized = true;
	}
	return emptyMesh;
}

struct Mesh
{
	@disable this();

	this(IBO ibo, VBO vbo)
	{
		_ibo = ibo;
		_vbo = vbo;
	}

	@property
	{
		auto ibo() inout { return _ibo; }
		auto vbo() inout { return _vbo; }
	}


	private	IBO	_ibo;
	private	VBO	_vbo;
}