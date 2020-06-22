Shader "Universal Render Pipeline/LCD Display/Unlit"
{
    Properties
    {
        [MainTexture] _BaseMap("Texture", 2D) = "white" {}
        [MainColor][HDR] _BaseColor("Color", Color) = (1, 1, 1, 1)
        _Cutoff("AlphaCutout", Range(0.0, 1.0)) = 0.5

        [NoScaleOffset] _PixelMask("Pixel Mask", 2D) = "white" {}
        _PixelLuma("Pixel Luma", Float) = 4.0
        [Enum(Square, 0, OffsetSquare, 1, Arrow, 2, Triangular, 3)] _PixelLayout("Pixel Layout", Float) = 0.0
        _PixelLayoutOffset("Pixel Layout Offset", Float) = 0.0

        // BlendMode
        [HideInInspector] _Surface("__surface", Float) = 0.0
        [HideInInspector] _Blend("__blend", Float) = 0.0
        [HideInInspector] _AlphaClip("__clip", Float) = 0.0
        [HideInInspector] _SrcBlend("Src", Float) = 1.0
        [HideInInspector] _DstBlend("Dst", Float) = 0.0
        [HideInInspector] _ZWrite("ZWrite", Float) = 1.0
        [HideInInspector] _Cull("__cull", Float) = 2.0

        // Editmode props
        [HideInInspector] _QueueOffset("Queue offset", Float) = 0.0

        // ObsoleteProperties
        [HideInInspector] _MainTex("BaseMap", 2D) = "white" {}
        [HideInInspector] _Color("Base Color", Color) = (0.5, 0.5, 0.5, 1)
        [HideInInspector] _SampleGI("SampleGI", float) = 0.0 // needed from bakedlit
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" "IgnoreProjector" = "True" "RenderPipeline" = "UniversalPipeline" "PreviewType"="Plane" }
        LOD 100

        Blend [_SrcBlend][_DstBlend]
        ZWrite [_ZWrite]
        Cull [_Cull]

        Pass
        {
            Name "Unlit"
            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x

            #pragma vertex vert
            #pragma fragment frag
            #pragma shader_feature _ALPHATEST_ON
            #pragma shader_feature _ALPHAPREMULTIPLY_ON

            #pragma shader_feature _PIXELLAYOUT_SQUARE _PIXELLAYOUT_OFFSET_SQUARE _PIXELLAYOUT_ARROW _PIXELLAYOUT_TRIANGULAR

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile_fog
            #pragma multi_compile_instancing

            #include "LCDDisplayUnlitInput.hlsl"
            #include "LCDDisplayCommon.hlsl"

            //#define _PIXEL_LAYOUT_SQUARE

            struct Attributes
            {
                float4 positionOS       : POSITION;
                float2 uv               : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float2 uv            : TEXCOORD0;
                float fogCoord       : TEXCOORD1;
                float4 positionCS    : SV_POSITION;

                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            half Remap01(half In, half2 InMinMax)
            {
                return (In - InMinMax.x) / (InMinMax.y - InMinMax.x);
            }

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertexInput.positionCS;
                output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
                output.fogCoord = ComputeFogFactor(vertexInput.positionCS.z);

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                float2 uv = input.uv;
                float2 duvdx = ddx(uv);
                float2 duvdy = ddy(uv);

                float2 dpdx = duvdx * _BaseMap_TexelSize.zw;
                float2 dpdy = duvdy * _BaseMap_TexelSize.zw;

                float2 pixelMaskUV;
                float2 pixelizedUV;

#if defined(_PIXELLAYOUT_SQUARE)
                pixelMaskUV = uv * _BaseMap_TexelSize.zw;
                pixelizedUV = floor(pixelMaskUV) + float2(0.5, 0.5);
                pixelizedUV /= _BaseMap_TexelSize.zw;

#elif defined(_PIXELLAYOUT_OFFSET_SQUARE)
                pixelMaskUV = uv * _BaseMap_TexelSize.zw;
                OffsetSquareCoordinate(pixelMaskUV, _PixelLayoutOffset, pixelizedUV);
                pixelizedUV /= _BaseMap_TexelSize.zw;

#elif defined(_PIXELLAYOUT_ARROW)
                pixelMaskUV = uv * _BaseMap_TexelSize.zw;
                ArrowCoordinate(pixelMaskUV, _PixelLayoutOffset, pixelizedUV);
                pixelizedUV /= _BaseMap_TexelSize.zw;

#elif defined(_PIXELLAYOUT_TRIANGULAR)
                pixelMaskUV = uv * _BaseMap_TexelSize.zw;
                TriangularCoordinate(pixelMaskUV, float2(_PixelLayoutOffset, 1.0), pixelizedUV);
                pixelizedUV /= _BaseMap_TexelSize.zw;
#endif

                half mipmapLevel = ComputeTextureLOD(dpdx, dpdy, _PixelMask_TexelSize.zw);

                half pixelization = saturate(Remap01(mipmapLevel, half2(1, 4)));
                half pixelremoval = saturate(Remap01(mipmapLevel, half2(3, 4)));

                uv = lerp(pixelizedUV, uv, pixelization);
                half4 texColor = SAMPLE_TEXTURE2D_GRAD(_BaseMap, sampler_BaseMap, uv, duvdx, duvdy);

                half4 pixelMaskColor = SAMPLE_TEXTURE2D_GRAD(_PixelMask, sampler_PixelMask, pixelMaskUV, dpdx, dpdy);
                pixelMaskColor *= _PixelLuma;
                pixelMaskColor = lerp(pixelMaskColor, half4(1, 1, 1, 1), pixelremoval);

                half3 color = texColor.rgb * pixelMaskColor.rgb * _BaseColor.rgb;
                half alpha = texColor.a * _BaseColor.a;
                AlphaDiscard(alpha, _Cutoff);

#ifdef _ALPHAPREMULTIPLY_ON
                color *= alpha;
#endif

                color = MixFog(color, input.fogCoord);
                alpha = OutputAlpha(alpha);

                return half4(color, alpha);
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            Cull[_Cull]

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing
            #pragma shader_feature _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "LCDDisplayUnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            // -------------------------------------
            // Material Keywords
            #pragma shader_feature _ALPHATEST_ON

            //--------------------------------------
            // GPU Instancing
            #pragma multi_compile_instancing

            #include "LCDDisplayUnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            // Required to compile gles 2.0 with standard srp library
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma vertex UniversalVertexMeta
            #pragma fragment UniversalFragmentMetaUnlit

            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitMetaPass.hlsl"

            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "UnityEditor.Rendering.Universal.ShaderGUI.LCDDisplayUnlitShader"
}
