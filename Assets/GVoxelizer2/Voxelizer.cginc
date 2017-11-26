// Geometry voxelizer effect
// https://github.com/keijiro/GVoxelizer2

#include "Common.cginc"
#include "UnityGBuffer.cginc"
#include "UnityStandardUtils.cginc"
#include "SimplexNoise3D.hlsl"

// Cube map shadow caster; Used to render point light shadows on platforms
// that lacks depth cube map support.
#if defined(SHADOWS_CUBE) && !defined(SHADOWS_CUBE_IN_DEPTH_TEX)
#define PASS_CUBE_SHADOWCASTER
#endif

// Base properties
half4 _Color;
half _Glossiness;
half _Metallic;
half3 _EmissionColor;

// Effect properties
half4 _Color2;
half _Glossiness2;
half _Metallic2;
half3 _EmissionColor2;

// Edge properties
half3 _EdgeColor;

// Dynamic properties
float _LocalTime;
float4 _EffectVector1;
float4 _EffectVector2;

// Vertex input attributes
struct Attributes
{
    float4 position : POSITION;
    float3 normal : NORMAL;
    float2 texcoord : TEXCOORD;
};

// Fragment varyings
struct Varyings
{
    float4 position : SV_POSITION;

#if defined(PASS_CUBE_SHADOWCASTER)
    // Cube map shadow caster pass
    float3 shadow : TEXCOORD0;

#elif defined(UNITY_PASS_SHADOWCASTER)
    // Default shadow caster pass

#else
    // GBuffer construction pass
    float3 normal : NORMAL;
    half3 ambient : TEXCOORD0;
    float4 edge : TEXCOORD1; // barycentric coord (xyz), emission (w)
    float4 wpos_ch : TEXCOORD2; // world position (xyz), channel select (w)

#endif
};

//
// Vertex stage
//

void Vertex(inout Attributes input)
{
    // Only do object space to world space transform.
    input.position = mul(unity_ObjectToWorld, input.position);
    input.normal = UnityObjectToWorldNormal(input.normal);
}

//
// Geometry stage
//

Varyings VertexOutput(float3 wpos, half3 wnrm, float4 edge, float channel)
{
    Varyings o;

#if defined(PASS_CUBE_SHADOWCASTER)
    // Cube map shadow caster pass: Transfer the shadow vector.
    o.position = UnityWorldToClipPos(float4(wpos, 1));
    o.shadow = wpos - _LightPositionRange.xyz;

#elif defined(UNITY_PASS_SHADOWCASTER)
    // Default shadow caster pass: Apply the shadow bias.
    float scos = dot(wnrm, normalize(UnityWorldSpaceLightDir(wpos)));
    wpos -= wnrm * unity_LightShadowBias.z * sqrt(1 - scos * scos);
    o.position = UnityApplyLinearShadowBias(UnityWorldToClipPos(float4(wpos, 1)));

#else
    // GBuffer construction pass
    o.position = UnityWorldToClipPos(float4(wpos, 1));
    o.normal = wnrm;
    o.ambient = ShadeSHPerVertex(wnrm, 0);
    o.edge = edge;
    o.wpos_ch = float4(wpos, channel);

#endif
    return o;
}

[maxvertexcount(24)]
void Geometry(
    triangle Attributes input[3], uint pid : SV_PrimitiveID,
    inout TriangleStream<Varyings> outStream
)
{
    // Input vertices
    float3 p0 = input[0].position.xyz;
    float3 p1 = input[1].position.xyz;
    float3 p2 = input[2].position.xyz;

    float3 n0 = input[0].normal;
    float3 n1 = input[1].normal;
    float3 n2 = input[2].normal;

    float3 center = (p0 + p1 + p2) / 3;

    // Deformation parameter
    float param = dot(_EffectVector1.xyz, center) + _EffectVector1.w;
    param = saturate(1 - param);

    // Draw nothing before the beginning of the deformation.
    if (param < 0) return;

    // Cube or triangle?
    uint seed = pid * 877;
    if (Random(seed) < 0.1)
    {
        // Cube animation
        float rnd = Random(seed + 1); // Random number

        float3 np = float3(rnd * 2378.34, _LocalTime * 0.8, 0);
        float4 snoise = snoise_grad(np); // Gradient noise

        float3 pos = center + snoise.xyz * 0.01; // Cube position
        float3 scale = 0.02 * param; // Cube scale animation
        scale *= abs(snoise.xyz);

        float edge = saturate(param * 5); // Edge color (emission power)

        // Cube points
        float3 c_p0 = pos + float3(-1, -1, -1) * scale;
        float3 c_p1 = pos + float3(+1, -1, -1) * scale;
        float3 c_p2 = pos + float3(-1, +1, -1) * scale;
        float3 c_p3 = pos + float3(+1, +1, -1) * scale;
        float3 c_p4 = pos + float3(-1, -1, +1) * scale;
        float3 c_p5 = pos + float3(+1, -1, +1) * scale;
        float3 c_p6 = pos + float3(-1, +1, +1) * scale;
        float3 c_p7 = pos + float3(+1, +1, +1) * scale;

        // Vertex outputs
        float3 c_n = float3(-1, 0, 0);
        outStream.Append(VertexOutput(c_p2, c_n, float4(0, 0, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p0, c_n, float4(1, 0, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p6, c_n, float4(0, 1, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p4, c_n, float4(1, 1, 0.5, edge), 0));
        outStream.RestartStrip();

        c_n = float3(1, 0, 0);
        outStream.Append(VertexOutput(c_p1, c_n, float4(0, 0, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p3, c_n, float4(1, 0, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p5, c_n, float4(0, 1, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p7, c_n, float4(1, 1, 0.5, edge), 0));
        outStream.RestartStrip();

        c_n = float3(0, -1, 0);
        outStream.Append(VertexOutput(c_p0, c_n, float4(0, 0, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p1, c_n, float4(1, 0, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p4, c_n, float4(0, 1, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p5, c_n, float4(1, 1, 0.5, edge), 0));
        outStream.RestartStrip();

        c_n = float3(0, 1, 0);
        outStream.Append(VertexOutput(c_p3, c_n, float4(0, 0, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p2, c_n, float4(1, 0, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p7, c_n, float4(0, 1, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p6, c_n, float4(1, 1, 0.5, edge), 0));
        outStream.RestartStrip();

        c_n = float3(0, 0, -1);
        outStream.Append(VertexOutput(c_p1, c_n, float4(0, 0, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p0, c_n, float4(1, 0, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p3, c_n, float4(0, 1, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p2, c_n, float4(1, 1, 0.5, edge), 0));
        outStream.RestartStrip();

        c_n = float3(0, 0, 1);
        outStream.Append(VertexOutput(c_p4, c_n, float4(0, 0, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p5, c_n, float4(1, 0, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p6, c_n, float4(0, 1, 0.5, edge), 0));
        outStream.Append(VertexOutput(c_p7, c_n, float4(1, 1, 0.5, edge), 0));
        outStream.RestartStrip();
    }
}

//
// Fragment phase
//

#if defined(PASS_CUBE_SHADOWCASTER)

// Cube map shadow caster pass
half4 Fragment(Varyings input) : SV_Target
{
    float depth = length(input.shadow) + unity_LightShadowBias.x;
    return UnityEncodeCubeShadowDepth(depth * _LightPositionRange.w);
}

#elif defined(UNITY_PASS_SHADOWCASTER)

// Default shadow caster pass
half4 Fragment() : SV_Target { return 0; }

#else

// GBuffer construction pass
void Fragment(
    Varyings input,
    out half4 outGBuffer0 : SV_Target0,
    out half4 outGBuffer1 : SV_Target1,
    out half4 outGBuffer2 : SV_Target2,
    out half4 outEmission : SV_Target3
)
{
    // PBS workflow conversion (metallic -> specular)
    half3 c1_diff, c1_spec, c2_diff, c2_spec;
    half not_in_use;

    c1_diff = DiffuseAndSpecularFromMetallic(
        _Color.rgb, _Metallic,   // input
        c1_spec, not_in_use      // output
    );

    c2_diff = DiffuseAndSpecularFromMetallic(
        _Color2.rgb, _Metallic2, // input
        c2_spec, not_in_use      // output
    );

    // Detect fixed-width edges with using screen space derivatives of
    // barycentric coordinates.
    float3 bcc = input.edge.xyz;
    float3 fw = fwidth(bcc);
    float3 edge3 = min(smoothstep(fw / 2, fw,     bcc),
                       smoothstep(fw / 2, fw, 1 - bcc));
    float edge = 1 - min(min(edge3.x, edge3.y), edge3.z);

    // Update the GBuffer.
    UnityStandardData data;
    float ch = input.wpos_ch.w;
    data.diffuseColor = lerp(c1_diff, c2_diff, ch);
    data.occlusion = 1;
    data.specularColor = lerp(c1_spec, c2_spec, ch);
    data.smoothness = lerp(_Glossiness, _Glossiness2, ch);
    data.normalWorld = input.normal;
    UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

    // Output ambient light and edge emission to the emission buffer.
    half3 sh = ShadeSHPerPixel(data.normalWorld, input.ambient, input.wpos_ch.xyz);
    outEmission = half4(sh * data.diffuseColor + _EdgeColor * input.edge.w * edge, 1);
}

#endif
