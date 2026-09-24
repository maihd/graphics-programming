struct Input
{
	float3 Position : TEXCOORD0;
	float2 UV : TEXCOORD1;
};

struct Output
{
	float4 Position : SV_Position;
	float2 UV : TEXCOORD0;
};

cbuffer UniformBlock : register(b0, space1) 
{
	column_major float4x4 mvp : packoffset(c0);
};

Output main(Input input)
{
	Output output;
	output.Position = mul(mvp, float4(input.Position, 1.0));
	output.UV = input.UV;

	return output;
}