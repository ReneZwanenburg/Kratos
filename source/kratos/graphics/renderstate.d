module kratos.graphics.renderstate;

import kratos.graphics.gl;



struct RenderState
{
	DepthTest	depthTest;

	void apply()
	{
		foreach(state; this.tupleof)
		{
			if(state !is typeof(state).current)
			{
				state.apply();
			}
		}
	}
}

enum DepthFunc : GLenum
{
	Never			= GL_NEVER,
	Less			= GL_LESS,
	Equal			= GL_EQUAL,
	LessOrEqual		= GL_LEQUAL,
	Greater			= GL_GREATER,
	NotEqual		= GL_NOTEQUAL,
	GreaterOrEqual	= GL_GEQUAL,
	Always			= GL_ALWAYS
}

struct DepthTest
{
	private static current = DepthTest(DepthFunc.Less, false, true);

	DepthFunc	func	= DepthFunc.LessOrEqual;
	bool		read	= true;
	bool		write	= true;

	void apply()
	{
		if(current.func != func)	gl.DepthFunc(func);
		if(current.read != read)	gl.setEnabled(GL_DEPTH_TEST, read);
		if(current.write != write)	gl.DepthMask(write);

		current = this;
	}
}