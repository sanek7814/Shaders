#include "ReShade.fxh"
uniform float g_sldHue <
        ui_label = "Tint Color";
        ui_type = "slider";
        ui_min = 0.0; ui_max = 1.0;
        ui_step = 0.01;
        > = 0.3;
uniform float g_sldIntensity <
        ui_label = "Tint Intensity";
        ui_type = "slider";
        ui_min = 0.0; ui_max = 1.0;
        ui_step = 0.01;
        > = 0.3;
        uniform float g_sldTemperature <
        ui_label = "Temperature";
        ui_type = "slider";
        ui_min = -1.0; ui_max = 1.0;
        ui_step = 0.01;
        > = 0.0;
float4 PS_Tint(float4 position : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
        float4 color = tex2D(ReShade::BackBuffer,texcoord.xy);
        /*
        float origluma = length(color.rgb);//dot(color.rgb,float3(0.299,0.587,0.114));
        float3 origchroma = color.rgb / (origluma + 1e-6);
        float3 tintchroma = saturate(float3(abs(g_sldHue * 6.0 - 3.0) - 1.0,
                                           2.0 - abs(g_sldHue * 6.0 - 2.0),
                                           2.0 - abs(g_sldHue * 6.0 - 4.0)));
        float tintluma = length(tintchroma); //dot(tintchroma,float3(0.299,0.587,0.114));
        tintchroma /= tintluma;
        color.rgb = lerp(origchroma,tintchroma,(1.0 - abs(dot(color.rgb,float3(0.299,0.587,0.114))*2.0-1.0)) * g_sldIntensity) * origluma;
        */
        //temperature approximation in YUV space. Conversion values: wikipedia
        float3 YUV;
        YUV.x = dot(color.xyz, float3(0.299, 0.587, 0.114));
        YUV.y = dot(color.xyz, float3(-0.14713, -0.28886, 0.436));
        YUV.z = dot(color.xyz, float3(0.615, -0.51499, -0.10001));
        YUV.y -= g_sldTemperature * YUV.x * 0.35;
        YUV.z += g_sldTemperature * YUV.x * 0.35;
        YUV.y += sin(g_sldHue * 6.283185307) * g_sldIntensity * g_sldIntensity * YUV.x; //g_sldIntensity^2 for a more natural slider response feel
        YUV.z += cos(g_sldHue * 6.283185307) * g_sldIntensity * g_sldIntensity * YUV.x;
        color.x = dot(YUV.xyz,float3(1.0,0.0,1.13983));
        color.y = dot(YUV.xyz,float3(1.0,-0.39465,-0.58060));
        color.z = dot(YUV.xyz,float3(1.0,2.03211,0.0));
        return color;
}

technique Nvdia_Mood
{
                pass
        {
                VertexShader = PostProcessVS;
                PixelShader = PS_Tint;
        }
}