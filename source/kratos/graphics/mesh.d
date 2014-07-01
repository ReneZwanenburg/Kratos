module kratos.graphics.mesh;

import kratos.resource.resource : Handle;
import kratos.graphics.bo;
import kratos.graphics.shadervariable;

alias Mesh = Handle!Mesh_Impl;

private struct Mesh_Impl
{
	@disable this(this);

	IBO ibo;
	VBO vbo;
	ShaderParameter[] vertexAttributes;
}