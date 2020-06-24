#ifndef UNIVERSAL_LCD_DISPLAY_LIT_INPUT_INCLUDED
#define UNIVERSAL_LCD_DISPLAY_LIT_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

#include "LCDDisplayCommon.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
float4 _EmissionMap_TexelSize;
float4 _PixelMask_TexelSize;
half4 _BaseColor;
half4 _SpecColor;
half4 _EmissionColor;
half _Cutoff;
half _Smoothness;
half _Metallic;
half _BumpScale;
half _OcclusionStrength;
half _PixelLuma;
half _PixelLayoutOffset;
CBUFFER_END

TEXTURE2D(_OcclusionMap);       SAMPLER(sampler_OcclusionMap);
TEXTURE2D(_MetallicGlossMap);   SAMPLER(sampler_MetallicGlossMap);
TEXTURE2D(_SpecGlossMap);       SAMPLER(sampler_SpecGlossMap);
TEXTURE2D(_PixelMask);          SAMPLER(sampler_PixelMask);

#ifdef _SPECULAR_SETUP
#define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, uv)
#else
#define SAMPLE_METALLICSPECULAR(uv) SAMPLE_TEXTURE2D(_MetallicGlossMap, sampler_MetallicGlossMap, uv)
#endif

half Remap01(half In, half2 InMinMax)
{
    return (In - InMinMax.x) / (InMinMax.y - InMinMax.x);
}

half3 SampleLCDDiplay(float2 uv, half3 emissionColor, TEXTURE2D_PARAM(emissionMap, sampler_emissionMap))
{
#ifndef _EMISSION
    return 0;
#else
    float2 duvdx = ddx(uv);
    float2 duvdy = ddy(uv);
    
    float2 dpdx = duvdx * _EmissionMap_TexelSize.zw;
    float2 dpdy = duvdy * _EmissionMap_TexelSize.zw;
    
    float2 pixelMaskUV;
    float2 pixelizedUV;

#if defined(_PIXELLAYOUT_SQUARE)
    pixelMaskUV = uv * _EmissionMap_TexelSize.zw;
    pixelizedUV = floor(pixelMaskUV) + float2(0.5, 0.5);
    pixelizedUV /= _EmissionMap_TexelSize.zw;

#elif defined(_PIXELLAYOUT_OFFSET_SQUARE)
    pixelMaskUV = uv * _EmissionMap_TexelSize.zw;
    OffsetSquareCoordinate(pixelMaskUV, _PixelLayoutOffset, pixelizedUV);
    pixelizedUV /= _EmissionMap_TexelSize.zw;

#elif defined(_PIXELLAYOUT_ARROW)
    pixelMaskUV = uv * _EmissionMap_TexelSize.zw;
    ArrowCoordinate(pixelMaskUV, _PixelLayoutOffset, pixelizedUV);
    pixelizedUV /= _EmissionMap_TexelSize.zw;

#elif defined(_PIXELLAYOUT_TRIANGULAR)
    pixelMaskUV = uv * _EmissionMap_TexelSize.zw;
    TriangularCoordinate(pixelMaskUV, float2(_PixelLayoutOffset, 1.0), pixelizedUV);
    pixelizedUV /= _EmissionMap_TexelSize.zw;
#endif

    half mipmapLevel = ComputeTextureLOD(dpdx, dpdy, _PixelMask_TexelSize.zw);

    half pixelization = saturate(Remap01(mipmapLevel, half2(1, 4)));
    half pixelremoval = saturate(Remap01(mipmapLevel, half2(3, 4)));

    uv = lerp(pixelizedUV, uv, pixelization);
    half3 color = SAMPLE_TEXTURE2D_GRAD(emissionMap, sampler_emissionMap, uv, duvdx, duvdy);

    half3 pixelMaskColor = SAMPLE_TEXTURE2D_GRAD(_PixelMask, sampler_PixelMask, pixelMaskUV, dpdx, dpdy).rgb;
    pixelMaskColor *= _PixelLuma;
    pixelMaskColor = lerp(pixelMaskColor, half3(1, 1, 1), pixelremoval);

    return color * pixelMaskColor * emissionColor;
#endif
}

half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
{
    half4 specGloss;

#ifdef _METALLICSPECGLOSSMAP
    specGloss = SAMPLE_METALLICSPECULAR(uv);
#ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
    specGloss.a = albedoAlpha * _Smoothness;
#else
    specGloss.a *= _Smoothness;
#endif
#else // _METALLICSPECGLOSSMAP
#if _SPECULAR_SETUP
    specGloss.rgb = _SpecColor.rgb;
#else
    specGloss.rgb = _Metallic.rrr;
#endif

#ifdef _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
    specGloss.a = albedoAlpha * _Smoothness;
#else
    specGloss.a = _Smoothness;
#endif
#endif

    return specGloss;
}

half SampleOcclusion(float2 uv)
{
#ifdef _OCCLUSIONMAP
    // TODO: Controls things like these by exposing SHADER_QUALITY levels (low, medium, high)
#if defined(SHADER_API_GLES)
    return SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
#else
    half occ = SAMPLE_TEXTURE2D(_OcclusionMap, sampler_OcclusionMap, uv).g;
    return LerpWhiteTo(occ, _OcclusionStrength);
#endif
#else
    return 1.0;
#endif
}

inline void InitializeLCDDisplayLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
{
    half4 albedoAlpha = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap));
    outSurfaceData.alpha = Alpha(albedoAlpha.a, _BaseColor, _Cutoff);

    half4 specGloss = SampleMetallicSpecGloss(uv, albedoAlpha.a);
    outSurfaceData.albedo = albedoAlpha.rgb * _BaseColor.rgb;

#if _SPECULAR_SETUP
    outSurfaceData.metallic = 1.0h;
    outSurfaceData.specular = specGloss.rgb;
#else
    outSurfaceData.metallic = specGloss.r;
    outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);
#endif

    outSurfaceData.smoothness = specGloss.a;
    outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap), _BumpScale);
    outSurfaceData.occlusion = SampleOcclusion(uv);
    outSurfaceData.emission = SampleLCDDiplay(uv, _EmissionColor.rgb, TEXTURE2D_ARGS(_EmissionMap, sampler_EmissionMap));
}

#endif // UNIVERSAL_LCD_DISPLAY_LIT_INPUT_INCLUDED