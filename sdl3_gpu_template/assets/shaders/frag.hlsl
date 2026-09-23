struct Input
{
	float2 UV : TEXCOORD0;
};

Texture2D<float4> Texture : register(t0, space2);
SamplerState Sampler : register(s0, space2);

float4 main(Input input) : SV_Target0
{
	return Texture.Sample(Sampler, input.UV);
	// return float4(1, 1, 1, 1);
}