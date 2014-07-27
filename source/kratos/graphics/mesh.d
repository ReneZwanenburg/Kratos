﻿module kratos.graphics.mesh;

import kratos.resource.resource;
import kratos.graphics.bo;
import kratos.graphics.shadervariable;

alias Mesh = Handle!Mesh_Impl;

// Provided for API consistency
Mesh mesh(IBO indices, VBO vertices, const ShaderParameter[] vertexAttributes)
{
	return Mesh(indices, vertices, vertexAttributes);
}

Mesh emptyMesh()
{
	static Mesh emptyMesh;
	static bool initialized = false;

	if(!initialized)
	{
		import kratos.graphics.gl;
		emptyMesh = mesh(ibo(null), vbo(null), [ShaderParameter(1, GL_FLOAT_VEC3, "position")]);
		initialized = true;
	}
	return emptyMesh;
}

private struct Mesh_Impl
{
	this(IBO ibo, VBO vbo, const ShaderParameter[] vertexAttributes)
	{
		assert(vbo.byteLength % vertexAttributes.totalByteSize == 0);
		assert(ibo.byteLength % uint.sizeof == 0);

		_ibo = ibo;
		_vbo = vbo;
		this.vertexAttributes = vertexAttributes;
	}

	@disable this(this);

	@property
	{
		auto ibo() const { return _ibo; }
		auto vbo() const { return _vbo; }
	}


	private			IBO					_ibo;
	private			VBO					_vbo;
	public const	ShaderParameter[]	vertexAttributes;
}