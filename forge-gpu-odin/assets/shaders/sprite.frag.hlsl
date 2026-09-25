struct PSInput
{
    float4 Position : SV_Position; /* not used, but required by pipeline */
    float2 UV    	: TEXCOORD0;   /* interpolated from vertex shader    */
};

Texture2D<float4> Texture : register(t0, space2);
SamplerState Sampler : register(s0, space2);

float4 main(PSInput input) : SV_Target
{
    return Texture.Sample(Sampler, input.UV);
}