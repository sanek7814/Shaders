#include "ReShade.fxh"
uniform float g_sldSharpen <
    ui_label = "g_sldSharpen";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
    > = 0.0;
uniform float g_sldClarity <
    ui_label = "g_sldClarity";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
    > = 0.0;
    uniform float g_sldHDR <
    ui_label = "g_sldHDR";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
    > = 0.0;
    uniform float g_sldBloom <
    ui_label = "g_sldBloom";
    ui_type = "slider";
    ui_min = 0.0; ui_max = 1.0;
    ui_step = 0.01;
    > = 0.0;
texture texOri
{
    Width = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = RGBA16F;
};
sampler samplerOri { Texture = texOri; };
static const float2 PixelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);

//#define vec2 float2
//#define vec3 float3
//#define vec4 float4
//#define mix lerp
float4 ScaleableGaussianBlurLinear(sampler    SamplerLinear,
                                   float2       texcoord,
                                   int          nSteps,
                                   float2       axis,
                                   float2       texelsize)
{
        float norm = -1.35914091423/(nSteps*nSteps);
        float4 accum = tex2D(SamplerLinear,texcoord.xy);
        float2 offsetinc = axis * texelsize;
    float divisor = 0.5; //exp(0) * 0.5
        [loop]
        for(float iStep = 1; iStep <= nSteps; iStep++)
        {
                float2 tapOffsetD = iStep * 2.0 + float2(-1.0,0.0);
                float2 tapWeightD = exp(tapOffsetD*tapOffsetD*norm);
                float tapWeightL = dot(tapWeightD,1.0);
                float tapOffsetL = dot(tapOffsetD,tapWeightD)/tapWeightL;
                accum += tex2D(SamplerLinear,texcoord.xy + offsetinc * tapOffsetL) * tapWeightL;
                accum += tex2D(SamplerLinear,texcoord.xy - offsetinc * tapOffsetL) * tapWeightL;
        divisor += tapWeightL;
        }
    accum /= 2.0 * divisor;
        return accum;
}
float4 BoxBlur(sampler SamplerLinear, float2 texcoord, float2 texelsize)
{
        float3 blurData[8] =
        {
                float3( 0.5, 1.5,1.50),
                float3( 1.5,-0.5,1.50),
                float3(-0.5,-1.5,1.50),
                float3(-1.5, 0.5,1.50),
                float3( 2.5, 1.5,1.00),
                float3( 1.5,-2.5,1.00),
                float3(-2.5,-1.5,1.00),
                float3(-1.5, 2.5,1.00),            
        };
        float4 blur = 0.0;
       
        for(int j=0; j<8; j++)
        {
blur += tex2D(SamplerLinear,texcoord.xy + blurData[j].xy * texelsize.xy) * blurData[j].z;
        }
        blur /= (4 * 1.5) + (4 * 1.0);
        return blur;        
}
float4 PS_LargeBlur1(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
        return ScaleableGaussianBlurLinear(ReShade::BackBuffer,texcoord.xy,15,float2(1,0),PixelSize.xy);
}
//
float4 PS_SharpenClarity(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
           float4 color = tex2D(ReShade::BackBuffer,texcoord.xy);
    float4 largeblur = ScaleableGaussianBlurLinear(samplerOri,texcoord.xy,15,float2(0,1),PixelSize.xy);
    float4 smallblur = BoxBlur(ReShade::BackBuffer,texcoord.xy,PixelSize);
    float a         = dot(color.rgb,float3(0.299,0.587,0.114));
    float sqrta         = sqrt(a);
    float b         = dot(largeblur.rgb,float3(0.299,0.587,0.114));
    float c            = dot(smallblur.rgb,float3(0.299,0.587,0.114));
//HDR Toning
    float HDRToning = sqrta * lerp(sqrta*(2*a*b-a-2*b+2.0), (2*sqrta*b-2*b+1), b > 0.5); //modified soft light v1
    color = color / (a+1e-6) * lerp(a,HDRToning,g_sldHDR);
//sharpen
    //float Sharpen = (a-c)/(g_sldSharpen*2.0+1e-6); //clamp to +- 1.0 / SHARPEN_AMOUNT with smooth falloff
    //Sharpen = sign(Sharpen)*(pow(Sharpen,6)-abs(Sharpen))/(pow(Sharpen,6)-1);
    //color += Sharpen*color*g_sldSharpen*2.0;
        float Sharpen = dot(color.rgb - smallblur.rgb,float3(0.299,0.587,0.114));
        float sharplimit = lerp(0.25,0.6,g_sldSharpen);
        Sharpen = clamp(Sharpen,-sharplimit,sharplimit);
        color.rgb = color.rgb / a * lerp(a,a+Sharpen,g_sldSharpen);
//clarity
        float Clarity = (0.5 + a - b);
        Clarity = lerp(2*Clarity + a*(1-2*Clarity), 2*(1-Clarity)+(2*Clarity-1)*rsqrt(a), a > b); //modified soft light v2
        color.rgb *= lerp(1.0,Clarity,g_sldClarity);
//bloom
        color.rgb = 1-(1-color.rgb)*(1-largeblur.rgb * g_sldBloom);
    return color;
}

technique Nvida_HDRToning
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_LargeBlur1;
        RenderTarget = texOri;
    }
        pass
    {
        VertexShader = PostProcessVS;
        PixelShader = PS_SharpenClarity;
    }
}