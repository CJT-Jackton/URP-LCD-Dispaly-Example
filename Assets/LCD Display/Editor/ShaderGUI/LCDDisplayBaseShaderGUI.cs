using System;
using UnityEngine;

namespace UnityEditor.Rendering.Universal.ShaderGUI
{
    public static class LCDDisplayBaseShaderGUI
    {
        public static class Styles
        {
            public static GUIContent pixelMaskText =
                new GUIContent("Pixel Mask Map", "Sets and configures the pixel mask map for the LCD Display.");

            public static GUIContent pixelLumaText =
                new GUIContent("Pixel Luma", "Sets the pixel luminace scale of the Pixel Mask map.");
        }

        public struct LCDDisplayProperties
        {
            public MaterialProperty pixelMask;
            public MaterialProperty pixelLuma;

            public LCDDisplayProperties(MaterialProperty[] properties)
            {
                pixelMask = BaseShaderGUI.FindProperty("_PixelMask", properties, false);
                pixelLuma = BaseShaderGUI.FindProperty("_PixelLuma", properties, false);
            }
        }

        public static void DoLCDDisplay(LCDDisplayProperties properties, MaterialEditor materialEditor)
        {
            materialEditor.TexturePropertySingleLine(Styles.pixelMaskText, properties.pixelMask, properties.pixelLuma);
        }
    }
}