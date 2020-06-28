#ifndef UNIVERSAL_LCD_DISPLAY_COMMON_INCLUDED
#define UNIVERSAL_LCD_DISPLAY_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Macros.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"

/////////////////////////////////////////////////////////////////////
//              Texture coordinate helper functions                //
/////////////////////////////////////////////////////////////////////
void ArrowCoordinate(inout float2 uv, float offset, out float2 cell)
{
    uv.x += distance(frac(uv.y), 0.5) * offset;

    cell = floor(uv);
    cell += float2(0.5 - 0.5 * offset, 0.5);
}

void OffsetSquareCoordinate(inout float2 uv, float offset, out float2 cell)
{
    bool isOddColumn = fmod(uv.x, 2.0) < 1.0;
    uv.y += isOddColumn ? 0.0 : offset;

    cell = floor(uv);
    cell += isOddColumn ? float2(0.5, 0.5) : float2(0.5, 0.5 - offset);
}

// tri: (x, y) is triangle's (height, width)
void TriangularCoordinate(inout float2 uv, float2 tri, out float2 cell)
{
    tri = normalize(tri);
    float offset = tri.y / tri.x;

    uv.x -= 0.5 - 1.25 * offset;

    float2 t = float2(3.0 * offset, 1.0);

    float2 a = fmod(uv, t);
    a.x += 0.5 - 1.25 * offset;

    float2 cellA = uv - a;
    cellA += float2(0.5, 0.5);

    float2 b = fmod(uv + float2(0.5 * t.x, 0.0), t);
    b.x += 0.5 - 1.25 * offset;

    float2 cellB = uv - b;
    cellB += float2(0.5, 0.5);

    b.y = 1.0 - b.y;

    float2 pos = a + float2(-0.5, 0.0);
    pos.x = abs(pos.x);

    float c = dot(pos, tri);
    float k = dot(float2(offset, 0.25), tri);
    
    if(c < k)
    {
        uv = a;
        cell = cellA;
    }
    else
    {
        uv = b;
        cell = cellB;
    }
}

/////////////////////////////////////////////////////////////////////
//                     Color Shift functions                       //
/////////////////////////////////////////////////////////////////////

half3 ApplyBrightnessLoss(half3 color, half luminanceOffset)
{
    half3 YCoCg = RGBToYCoCg(color);
    YCoCg.r = saturate(YCoCg.r + luminanceOffset);
    return YCoCgToRGB(YCoCg);
}

// IPS (in-plane switching) Panel
// Data Source: LG 27UK650-W
//  - https://www.rtings.com/monitor/reviews/lg/27uk650-w
half3 ColorWashoutHorizontalIPS(half cosH)
{
    half s = sin(HALF_PI * cosH);
    half r = lerp(s, cosH, 0.314);
    half g = lerp(s, cosH, 0.5);
    half b = lerp(s, cosH, 0.72);

    return half3(r, g, b);
}

half3 ColorWashoutVerticalIPS(half cosV)
{
    half r = cosV + 1.0 / 4.57 * PositivePow(sin(PI * PositivePow(cosV, 0.76)), 6.5);
    half g = cosV + 1.0 / 4.05 * PositivePow(sin(PI * PositivePow(cosV, 0.73)), 5.43);
    half b = cosV + 1.0 / 3.07 * PositivePow(sin(PI * PositivePow(cosV, 0.694)), 3.25);

    return half3(r, g, b);
}

// VA (Vertical Alignment) Panel
// Data Source: Philips Momentum 436M6VBPAB
//  - https://www.rtings.com/monitor/reviews/philips/momentum-436m6vbpab
half3 ColorWashoutHorizontalVA(half cosH)
{
    half r = cosH + 1.0 / 5.1 * sin(PI * PositivePow(cosH, 0.5)) - 1.0 / 20.0 * sin(PI * PositivePow(cosH, 4.5));
    half g = cosH + 1.0 / 4.14 * sin(PI * PositivePow(cosH, 0.5)) - 1.0 / 22.7 * sin(PI * PositivePow(cosH, 4.5));
    half b = cosH + 1.0 / 6.05 * sin(PI * PositivePow(cosH, 0.44)) - 1.0 / 19.0 * sin(PI * PositivePow(cosH, 3.43));

    return half3(r, g, b);
}

half3 ColorWashoutVerticalVA(half cosV)
{
    half r = cosV + 1.0 / 4.15 * sin(PI * PositivePow(cosV, 0.5)) - 1.0 / 6.5 * sin(PI * PositivePow(cosV, 2.3));
    half g = cosV + 1.0 / 3.8 * sin(PI * PositivePow(cosV, 0.5)) - 1.0 / 6.96 * sin(PI * PositivePow(cosV, 2.2));
    half b = cosV + 1.0 / 4.7 * sin(PI * PositivePow(cosV, 0.64)) - 1.0 / 5.6 * sin(PI * PositivePow(cosV, 2.1));

    return half3(r, g, b);
}

half BrightnessLossHorizontalVA(half luminance, half cosH)
{   
    return 1.0 / 3.6 * sin(PI * PositivePow(1.0 - luminance, 1.32)) * sin(PI * PositivePow(cosH, 0.78));
}

half BrightnessLossVerticalVA(half luminance, half cosV)
{   
    return 1.0 / 3.5 * sin(PI * PositivePow(1.0 - luminance, 2.0)) * sin(PI * PositivePow(cosV, 0.65));
}

// TN (Twisted Nematic) Panel
// Data Source: Dell S2716DG
//  - https://www.rtings.com/monitor/reviews/dell/s2716dgr-s2716dg
half3 ColorWashoutHorizontalTN(half cosH)
{
    return half3(cosH, cosH, cosH);
}

half3 ColorWashoutVerticalTN(half cosV)
{
    return half3(cosV, cosV, cosV);
}

void ColorWashout(inout half3 color, half3 viewDir, half3 normal, half3 horizontalDir, half3 verticalDir)
{
    half3 viewProj = cross(SafeNormalize(cross(normal, viewDir)), normal);
    float NdotV = dot(viewDir, normal);

    half3 colorWashoutH, colorWashoutV;

#if _COLORWASHOUT_SIMPLE
    color *= SRGBToLinear(NdotV);
#elif _COLORWASHOUT_IPS
    colorWashoutH = ColorWashoutHorizontalIPS(NdotV);
    colorWashoutV = ColorWashoutVerticalIPS(NdotV);

    colorWashoutH = SRGBToLinear(colorWashoutH);
    colorWashoutV = SRGBToLinear(colorWashoutV);

    float t = acos(saturate(abs(dot(viewProj, horizontalDir)))) * INV_HALF_PI;

    color *= lerp(colorWashoutH, colorWashoutV, saturate(t));
    //color *= lerp(colorWashoutH, colorWashoutV, smoothstep(0.0, 1.0, t));
#elif _COLORWASHOUT_VA
    colorWashoutH = ColorWashoutHorizontalVA(NdotV);
    colorWashoutV = ColorWashoutVerticalVA(NdotV);

    colorWashoutH = SRGBToLinear(colorWashoutH);
    colorWashoutV = SRGBToLinear(colorWashoutV);

    half3 sRGBcolor = LinearToSRGB(color);
    half luminance = Luminance(sRGBcolor);

    half bH = BrightnessLossHorizontalVA(luminance, NdotV);
    half bV = BrightnessLossVerticalVA(luminance, NdotV);

    float t = acos(saturate(abs(dot(viewProj, horizontalDir)))) * INV_HALF_PI;

    half luminanceOffset = lerp(bH, bV, t);

    color = SRGBToLinear(ApplyBrightnessLoss(sRGBcolor, luminanceOffset));
    color *= lerp(colorWashoutH, colorWashoutV, t);
#elif _COLORWASHOUT_TN
    colorWashoutH = ColorWashoutHorizontalTN(NdotV);
    colorWashoutV = ColorWashoutVerticalTN(NdotV);

    colorWashoutH = SRGBToLinear(colorWashoutH);
    colorWashoutV = SRGBToLinear(colorWashoutV);

    float t = acos(saturate(abs(dot(viewProj, horizontalDir)))) * INV_HALF_PI;

    color *= lerp(colorWashoutH, colorWashoutV, saturate(t));
#endif
}

#endif // UNIVERSAL_LCD_DISPLAY_COMMON_INCLUDED