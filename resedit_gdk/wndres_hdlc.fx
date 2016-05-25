float3 leftColor = { 1, 0, 0 };
float3 rightColor = { 0, 1, 0 };

float4 hdlc( float2 coord : TEXCOORD0 ) : COLOR0
{
	return float4(leftColor * (1 - coord.x) + rightColor * coord.x, 1);
}

technique hdlc_standard
{
	pass std
	{
		PixelShader = compile ps_2_0 hdlc();
	}
}