uniform float Sharpening <
    ui_type = "slider";
    ui_label = "Sharpening";
    ui_min = 0.0;
   ui_max = 1.0;
    ui_step=0.1;
    > = 0.5;
#include "ReShade.fxh"
static const float AspectRatio = BUFFER_WIDTH * BUFFER_RCP_HEIGHT;
static const float2 PixelSize = float2(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT);
static const float2 ScreenSize = float2(BUFFER_WIDTH, BUFFER_HEIGHT);
texture TexColor : COLOR;
sampler sTexColor {Texture = TexColor; SRGBTexture = true;};
#define min3(a, b, c) min(a, min(b, c))
#define max3(a, b, c) max(a, max(b, c))
// This is set at the limit of providing unnatural results for sharpening.
#define FSR_RCAS_LIMIT (0.25-(5.0/16.0))
float3 CASPass(float4 vpos : SV_Position, float2 texcoord : TexCoord) : SV_Target
{
    // Algorithm uses minimal 3x3 pixel neighborhood.
    //    b
    //  d e f
    //    h
    float3 b = tex2Doffset(sTexColor, texcoord, int2(0, -1)).rgb;
    float3 d = tex2Doffset(sTexColor, texcoord, int2(-1, 0)).rgb;
    float3 e = tex2D(sTexColor, texcoord).rgb;
    float3 f = tex2Doffset(sTexColor, texcoord, int2(1, 0)).rgb;
    float3 h = tex2Doffset(sTexColor, texcoord, int2(0, 1)).rgb;
    // Rename (32-bit) or regroup (16-bit).
    float bR = b.r;
    float bG = b.g;
    float bB = b.b;
    float dR = d.r;
    float dG = d.g;
    float dB = d.b;
    float eR = e.r;
    float eG = e.g;
    float eB = e.b;
    float fR = f.r;
    float fG = f.g;
    float fB = f.b;
    float hR = h.r;
    float hG = h.g;
    float hB = h.b;
    float nz;
    // Luma times 2.
    float bL = bB * 0.5 + (bR * 0.5 + bG);
    float dL = dB * 0.5 + (dR * 0.5 + dG);
    float eL = eB * 0.5 + (eR * 0.5 + eG);
    float fL = fB * 0.5 + (fR * 0.5 + fG);
    float hL = hB * 0.5 + (hR * 0.5 + hG);
    // Noise detection.
    nz = 0.25 * bL + 0.25 * dL + 0.25 * fL + 0.25 * hL - eL;
    nz = saturate(abs(nz) * rcp(max3(max3(bL, dL, eL), fL, hL) - min3(min3(bL, dL, eL), fL, hL)));
    nz = -0.5 * nz + 1.0;
    // Min and max of ring.
    float mn4R = min(min3(bR, dR, fR), hR);
    float mn4G = min(min3(bG, dG, fG), hG);
    float mn4B = min(min3(bB, dB, fB), hB);
    float mx4R = max(max3(bR, dR, fR), hR);
    float mx4G = max(max3(bG, dG, fG), hG);
    float mx4B = max(max3(bB, dB, fB), hB);
    // Immediate constants for peak range.
    float2 peakC = float2( 1.0, -1.0 * 4.0 );
    // Limiters, these need to be high precision RCPs.
    float hitMinR = min(mn4R, eR) * rcp(4.0 * mx4R);
    float hitMinG = min(mn4G, eG) * rcp(4.0 * mx4G);
    float hitMinB = min(mn4B, eB) * rcp(4.0 * mx4B);
    float hitMaxR = (peakC.x - max(mx4R, eR)) * rcp(4.0 * mn4R + peakC.y);
    float hitMaxG = (peakC.x - max(mx4G, eG)) * rcp(4.0 * mn4G + peakC.y);
    float hitMaxB = (peakC.x - max(mx4B, eB)) * rcp(4.0 * mn4B + peakC.y);
    float lobeR = max(-hitMinR, hitMaxR);
    float lobeG = max(-hitMinG, hitMaxG);
    float lobeB = max(-hitMinB, hitMaxB);
    float lobe = max(-FSR_RCAS_LIMIT, min(max3(lobeR, lobeG, lobeB), 0)) * Sharpening;
    // Apply noise removal.
    lobe *= nz;
    // Resolve, which needs the medium precision rcp approximation to avoid visible tonality changes.
    float rcpL = rcp(4.0 * lobe + 1.0);
    float3 c = float3(
        (lobe * bR + lobe * dR + lobe * hR + lobe * fR + eR) * rcpL,
        (lobe * bG + lobe * dG + lobe * hG + lobe * fG + eG) * rcpL,
        (lobe * bB + lobe * dB + lobe * hB + lobe * fB + eB) * rcpL
    );
    return c;
}
technique CASPass
    <
    ui_label = "CAS Pass";
    ui_tooltip =
    "CAS is a low overhead adaptive sharpening algorithm that AMD includes with their drivers.\n"
    "This port to Reshade works with all cards from all vendors,\n"
    "but cannot do the optional scaling that CAS is normally also capable of when activated in the AMD drivers.\n"
    "\n"
    "The algorithm adjusts the amount of sharpening per pixel to target an even level of sharpness across the image.\n"
    "Areas of the input image that are already sharp are sharpened less, while areas that lack detail are sharpened more.\n"
    "This allows for higher overall natural visual sharpness with fewer artifacts.";
    >
{
    pass
    {
        VertexShader = PostProcessVS;
        PixelShader = CASPass;
        SRGBWriteEnable = true;
    }
}