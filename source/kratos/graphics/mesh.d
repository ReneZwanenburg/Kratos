module kratos.graphics.mesh;

import kratos.graphics.bo;
import kratos.resource.resource : ResourceIdentifier;

Mesh emptyMesh()
{
	static Mesh emptyMesh = void;
	static bool initialized = false;

	if(!initialized)
	{
		import kgl3n.vector;
		static struct S{ vec3 position; }
		S[] sArr;
		uint[] iArr;

		emptyMesh = Mesh(IBO(iArr), VBO(sArr));
		initialized = true;
	}
	return emptyMesh;
}

struct Mesh
{
	ResourceIdentifier id;

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