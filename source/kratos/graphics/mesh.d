module kratos.graphics.mesh;

import kgl3n.vector : vec2, vec3;
import kratos.graphics.bo;

import kratos.resource.manager : Manager;

alias MeshManager = Manager!Mesh_Impl;
alias Mesh = MeshManager.Handle;

Mesh emptyMesh()
{
	static Mesh emptyMesh;

	if(!emptyMesh.refCountedStore.isInitialized)
	{
		static struct S{ vec3 position; }
		S[] sArr;
		uint[] iArr;
		
		emptyMesh = MeshManager.create(IBO(iArr), VBO(sArr));
	}
	
	return emptyMesh;
}

Mesh quad2D(vec2 from, vec2 to, vec2 texFrom = vec2(0, 0), vec2 texTo = vec2(1, 1))
{
	static struct Vertex
	{
		vec2 position;
		vec2 texCoord0;
	}

	auto vbo = VBO([
			Vertex(vec2(from.x,	to.y),		vec2(texFrom.x,	texTo.y)	),
			Vertex(vec2(to.x,	to.y),		vec2(texTo.x,	texTo.y)	),
			Vertex(vec2(from.x,	from.y),	vec2(texFrom.x,	texFrom.y)	),
			Vertex(vec2(to.x,	from.y),	vec2(texTo.x,	texFrom.y)	)
		]);
	
	return MeshManager.create(quadIBO, vbo);
}

private IBO quadIBO()
{
	static IBO ibo = void;
	static bool initialized = false;
	
	if(!initialized)
	{
		initialized = true;
		
		ushort[] indices = [0, 2, 1, 1, 2, 3];
		ibo = IBO(indices);
	}
	
	return ibo;
}

class Mesh_Impl
{
	string name;

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