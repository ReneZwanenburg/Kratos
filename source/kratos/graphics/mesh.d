module kratos.graphics.mesh;

import kratos.resource.resource : Handle;
import kratos.graphics.bo;
import kratos.graphics.shadervariable;

alias Mesh = Handle!Mesh_Impl;

private struct Mesh_Impl
{
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