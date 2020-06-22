#ifndef UNIVERSAL_LCD_DISPLAY_COMMON_INCLUDED
#define UNIVERSAL_LCD_DISPLAY_COMMON_INCLUDED

#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Macros.hlsl"

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
//                  Color Shift functions                          //
/////////////////////////////////////////////////////////////////////
void brightnessLossVertical(inout half brightness, half angle)
{
    brightness *= 1;
}

void brightnessLossHorizontal(inout half brightness, half angle)
{
    brightness *= cos(HALF_PI * pow(angle, 1.04)) * (1 - pow(angle, 8.8));
}

void brightnessLoss(inout half brightness, half3 viewDir, half3 normal, half3 horizontalDir, half3 verticalDir)
{
    // The projection of view direction vector on the surface plane
    // http://www.euclideanspace.com/maths/geometry/elements/plane/lineOnPlane/index.htm
    half3 viewProj = cross(cross(normal, viewDir), normal);

    float angleH = acos(dot(viewProj, horizontalDir)) * INV_PI;
    float angleV = acos(dot(viewProj, verticalDir)) * INV_PI;

    brightnessLossHorizontal(brightness, angleH);
    brightnessLossVertical(brightness, angleV);
}

void ColorWashoutHorizontalIPS(inout half3 color, half angle)
{
    half r = cos(HALF_PI * angle) + 0.25 * (1 / (abs(angle - 0.4) + 1) - 1 / 1.4);
    half g = cos(HALF_PI * angle) + 0.185 * (1 / (abs(angle - 0.4) + 1) - 1 / 1.4);
    half b = cos(HALF_PI * angle);

    color *= half3(r, g, b);
}

void ColorWashoutVerticalIPS(inout half3 color, half angle)
{
    half r = cos(HALF_PI * angle) + 0.25 * (1 / (abs(angle - 0.4) + 1) - 1 / 1.4);
    half g = cos(HALF_PI * angle) + 0.185 * (1 / (abs(angle - 0.4) + 1) - 1 / 1.4);
    half b = cos(HALF_PI * angle);

    color *= half3(r, g, b);
}

void ColorWashout(inout half3 color, half3 viewDir, half3 normal, half3 horizontalDir, half3 verticalDir)
{
    // The projection of view direction vector on the surface plane
    // http://www.euclideanspace.com/maths/geometry/elements/plane/lineOnPlane/index.htm
    half3 viewProj = cross(cross(normal, viewDir), normal);

    float angleH = dot(viewProj, horizontalDir);
    float angleV = dot(viewProj, verticalDir);

    ColorWashoutHorizontalIPS(color, abs(angleH));
    ColorWashoutVerticalIPS(color, abs(angleV));
}

#endif // UNIVERSAL_LCD_DISPLAY_COMMON_INCLUDED