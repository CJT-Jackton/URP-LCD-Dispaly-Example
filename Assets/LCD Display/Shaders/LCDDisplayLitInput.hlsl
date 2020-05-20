#ifndef UNIVERSAL_LCD_DISPLAY_LIT_INPUT_INCLUDED
#define UNIVERSAL_LCD_DISPLAY_LIT_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

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
    float2 pixelMaskUV = uv * _EmissionMap_TexelSize.zw;
    float2 pixelMaskTexcoord = pixelMaskUV * _PixelMask_TexelSize.zw;

    // The OpenGL Graphics System: A Specification 4.2
    //  - chapter 3.9.11, equation 3.21
    half2 duvdx = ddx(pixelMaskTexcoord);
    half2 duvdy = ddy(pixelMaskTexcoord);

    half scaleFactor = max(dot(duvdx, duvdx), dot(duvdy, duvdy));
    half mipmapLevel = 0.5 * log2(scaleFactor);
    //half mipmapLevel = ComputeTextureLOD(pixelMaskUV, _PixelMask_TexelSize.zw);

    half pixelization = saturate(Remap01(mipmapLevel, half2(1, 4)));
    half pixelremoval = saturate(Remap01(mipmapLevel, half2(3, 4)));

    half2 pixelizedUV = floor(pixelMaskUV) + half2(0.5, 0.5);
    pixelizedUV /= _EmissionMap_TexelSize.zw;

    uv = lerp(pixelizedUV, uv, pixelization);
    half3 color = SAMPLE_TEXTURE2D(emissionMap, sampler_emissionMap, uv).rgb;

    half3 pixelMaskColor = SAMPLE_TEXTURE2D(_PixelMask, sampler_PixelMask, pixelMaskUV).rgb;
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

inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
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