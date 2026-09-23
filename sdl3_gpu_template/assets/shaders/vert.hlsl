struct Input
{
	float3 Position : TEXCOORD0;
	float2 UV : TEXCOORD1;
};

struct Output
{
	float2 UV : TEXCOORD0;
	float4 Position : SV_Position;
};

cbuffer UniformBlock : register(b0, space1) 
{
	float4x4 mvp : packoffset(c0);
};

Output main(Input input)
{
	Output output;
	output.UV = input.UV;
	output.Position = mul(mvp, float4(input.Position, 1.0f));

	return output;
}