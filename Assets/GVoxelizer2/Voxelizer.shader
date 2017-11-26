// Geometry voxelizer effect
// https://github.com/keijiro/GVoxelizer2

Shader "GVoxelizer2/Voxelizer"
{
    Properties
    {
        _Color("Albedo", Color) = (1, 1, 1, 1)
        _Glossiness("Smoothness", Range(0, 1)) = 0.5
        [Gamma] _Metallic("Metallic", Range(0, 1)) = 0

        [Header(Surface Emission Colors)]
        [HDR] _Emission1("Primary", Color) = (0, 0, 0)
        [HDR] _Emission2("Secondary", Color) = (0, 0, 0)
        [HDR] _Emission3("Additional", Color) = (0, 0, 0)

        [Header(Edge Emission Colors)]
        [HDR] _EdgeColor1("Primary", Color) = (0, 0, 0)
        [HDR] _EdgeColor2("Secondary", Color) = (0, 0, 0)

        [Header(Animation)]
        _Density("Voxel Density", Float) = 0.1
        _VoxelSize("Voxel Size", Float) = 0.02
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
