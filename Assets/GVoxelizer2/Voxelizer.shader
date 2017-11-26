// Geometry voxelizer effect
// https://github.com/keijiro/GVoxelizer2

Shader "GVoxelizer2/Voxelizer"
{
    Properties
    {
        [Header(Base Properties)]
        _Color("Color", Color) = (1, 1, 1, 1)
        _Glossiness("Smoothness", Range(0, 1)) = 0.5
        [Gamma] _Metallic("Metallic", Range(0, 1)) = 0
        [HDR] _EmissionColor("Emission", Color) = (0, 0, 0)

        [Header(Effect Properties)]
        _Color2("Color", Color) = (0, 0, 0, 0)
        _Glossiness2("Smoothness", Range(0, 1)) = 0
        [Gamma] _Metallic2("Metallic", Range(0, 1)) = 0
        [HDR] _EmissionColor2("Emission", Color) = (0, 0, 0)

        [Header(Edge Properteis)]
        [HDR] _EdgeColor("Color", Color) = (1, 0, 0)

        [Space]
        _Scatter("Scatter Amount", Float) = 0.1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            Tags { "LightMode"="Deferred" }
            CGPROGRAM
            #pragma target 4.0
            #pragma vertex Vertex
            #pragma geometry Geometry
            #pragma fragment Fragment
            #pragma multi_compile_prepassfinal noshadowmask nodynlightmap nodirlightmap nolightmap
            #include "Voxelizer.cginc"
            ENDCG
        }
        Pass
        {
            Tags { "LightMode"="ShadowCaster" }
            CGPROGRAM
            #pragma target 4.0
            #pragma vertex Vertex
            #pragma geometry Geometry
            #pragma fragment Fragment
            #pragma multi_compile_prepassfinal noshadowmask nodynlightmap nodirlightmap nolightmap
            #define UNITY_PASS_SHADOWCASTER
            #include "Voxelizer.cginc"
            ENDCG
        }
    }
}
