module kgl3n.ext.hsv;

import std.conv : to;

import kgl3n.vector;
import kgl3n.math : min, max, floor, PI;

version(unittest) {
    import kgl3n.math : almostEqual;
}

/// Converts a 3 dimensional color-vector from the RGB to the HSV colorspace.
/// The function assumes that each component is in the range [0, 1].
/// The output hue is in radians, NOT degrees.
@safe pure nothrow vec3 rgbToHsv(vec3 rgb)
{
	vec3 hsv;

	float cmax = max(rgb.r, rgb.g, rgb.b);
	float cmin = min(rgb.r, rgb.g, rgb.b);
	float cdelta = cmax - cmin;
	
	hsv.z = cmax;

	if (cmax != 0)
	{
		hsv.y = cdelta / cmax;
	}
	else
	{
		hsv.y = 0;
	}
	if (hsv.y == 0)
	{
		hsv.x = 0;
	}
	else
	{
		float redc = (cmax - rgb.r) / cdelta;
		float greenc = (cmax - rgb.g) / cdelta;
		float bluec = (cmax - rgb.b) / cdelta;
		if (rgb.r == cmax)
		{
			hsv.x = bluec - greenc;
		}
		else if (rgb.g == cmax)
		{
			hsv.x = 2.0f + redc - bluec;
		}
		else
		{
			hsv.x = 4.0f + greenc - redc;
		}

		hsv.x *= (PI * 2) / 6.0f;
		if (hsv.x < 0)
		{
			hsv.x += PI * 2;
		}
	}

	return hsv;
}

/// Converts a 4 dimensional color-vector from the RGB to the HSV colorspace.
/// The alpha value is not touched. This function also assumes that each component is in the range [0, 1].
@safe pure nothrow vec4 rgbToHsv(vec4 inp)
{
    return vec4(inp.rgb.rgbToHsv, inp.a);
}

unittest
{
    assert(rgbToHsv(vec3(0.0f, 0.0f, 0.0f)) == vec3(0.0f, 0.0f, 0.0f));
    assert(rgbToHsv(vec3(1.0f, 1.0f, 1.0f)) == vec3(0.0f, 0.0f, 1.0f));

    vec3 hsv = rgbToHsv(vec3(100.0f/255.0f, 100.0f/255.0f, 100.0f/255.0f));    
    assert(hsv.x == 0.0f && hsv.y == 0.0f && almostEqual(hsv.z, 0.392157, 0.000001));
    
    assert(rgbToHsv(vec3(0.0f, 0.0f, 1.0f)) == vec3((240.0f / 360) * PI * 2, 1.0f, 1.0f));
}

/// Converts a 3 dimensional color-vector from the HSV to the RGB colorspace.
/// RGB colors will be in the range [0, 1].
/// This function is not marked es pure, since it depends on std.math.floor, which
/// is also not pure.
@safe nothrow vec3 hsvToRgb(vec3 hsv)
{
	if (hsv.y == 0)
	{
		return vec3(hsv.z);
	}
	else
	{
		float normalizedHue = hsv.x / (PI * 2);
		float h = ((normalizedHue - floor(normalizedHue)) * 6.0f);
		float f = h - floor(h);
		float p = hsv.z * (1.0f - hsv.y);
		float q = hsv.z * (1.0f - hsv.y * f);
		float t = hsv.z * (1.0f - (hsv.y * (1.0f - f)));

		float hf = floor(h);
		if(hf == 0f)		return vec3(hsv.z, t, p);
		else if(hf == 1)	return vec3(q, hsv.z, p);
		else if(hf == 2)	return vec3(p, hsv.z, t);
		else if(hf == 3)	return vec3(p, q, hsv.z);
		else if(hf == 4)	return vec3(t, p, hsv.z);
		else if(hf == 5)	return vec3(hsv.z, p, q);
		else assert(false);
	}
}

/// Converts a 4 dimensional color-vector from the HSV to the RGB colorspace.
/// The alpha value is not touched and the resulting RGB colors will be in the range [0, 1].
@safe nothrow vec4 hsvToRgb(vec4 inp)
{
    return vec4(inp.xyz.hsvToRgb, inp.w);
}

unittest
{
    assert(hsvToRgb(vec3(0.0f, 0.0f, 0.0f)) == vec3(0.0f, 0.0f, 0.0f));
    assert(hsvToRgb(vec3(0.0f, 0.0f, 1.0f)) == vec3(1.0f, 1.0f, 1.0f));

    vec3 rgb = hsvToRgb(vec3(0.0f, 0.0f, 0.392157f));
    assert(rgb == vec3(0.392157f, 0.392157f, 0.392157f));

	assert(hsvToRgb(vec3((300.0f / 360) * PI * 2, 1.0f, 1.0f)) == vec3(1.0f, 0.0f, 1.0f));
}