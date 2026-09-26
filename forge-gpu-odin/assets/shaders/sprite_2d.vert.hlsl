struct VSInput
{
    float2 Position : TEXCOORD0;
    float2 UV    	: TEXCOORD1;
};

struct VSOutput
{
    float4 Position : SV_Position;
    float2 UV    	: TEXCOORD0;
};

cbuffer Uniform : register(b0, space1)
{
    column_major float4x4 mvp;
};

VSOutput main(VSInput input)
{
    VSOutput output;
    output.Position = mul(mvp, float4(input.Position, 0.0, 1.0));
    output.UV    	= input.UV;
    return output;
}