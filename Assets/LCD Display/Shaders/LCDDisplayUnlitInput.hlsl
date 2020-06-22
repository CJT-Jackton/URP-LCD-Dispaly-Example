#ifndef UNIVERSAL_LCD_DISPLAY_UNLIT_INPUT_INCLUDED
#define UNIVERSAL_LCD_DISPLAY_UNLIT_INPUT_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

CBUFFER_START(UnityPerMaterial)
float4 _BaseMap_ST;
float4 _BaseMap_TexelSize;
float4 _PixelMask_TexelSize;
half4 _BaseColor;
half _Cutoff;
half _PixelLuma;
half _PixelLayoutOffset;
CBUFFER_END

TEXTURE2D(_PixelMask);            SAMPLER(sampler_PixelMask);

#endif // UNIVERSAL_LCD_DISPLAY_UNLIT_INPUT_INCLUDED