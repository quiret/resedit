static const float PI = 3.14159265f;
uniform float brightness = 1;

// Docu: http://chilliant.blogspot.de/2010/11/rgbhsv-in-hlsl.html
float3 HUEtoRGB(in float H)
{
	float R = abs(H * 6 - 3) - 1;
	float G = 2 - abs(H * 6 - 2);
	float B = 2 - abs(H * 6 - 4);
	return saturate(float3(R,G,B));
}

float4 circleMain( float2 coord : TEXCOORD0 ) : COLOR0
{
	float2 off = float2(0.5, 0.5) - coord;
	
	// Draw a circle
	clip(0.25 - (off.x * off.x + off.y * off.y));
	
	float angle = atan2(off.y, off.x) / PI / 2;

	return float4(brightness - HUEtoRGB(angle < 0 ? angle + 1 : angle) * length(off) * 2 * brightness, 1);
}

technique colorCircle
{
	pass main
	{
		PixelShader = compile ps_2_0 circleMain();
	}
}