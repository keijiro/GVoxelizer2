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

// Emission Colors
half3 _Emission1, _Emission2, _Emission3;
half3 _EdgeColor1, _EdgeColor2;

// Animation parameters
float _Density;
float _VoxelSize;
float _Scatter;

// Effector parameters
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
    float3 wpos : TEXCOORD1;
    float2 edge : TEXCOORD2; // In-quad coordinates used in edge detection
    half3 emission : TEXCOORD3; // Power (x), channel (y) and addition (z)

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

Varyings VertexOutput(float3 wpos, half3 wnrm, float2 edge, half3 emission)
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
    o.wpos = wpos;
    o.edge = edge;
    o.emission = emission;

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
    float3 center = (p0 + p1 + p2) / 3;

    // Use the 1st normal vector as a triangle normal.
    float3 normal = input[0].normal;

    // Deformation parameter
    float param = dot(_EffectVector1.xyz, center) - _EffectVector1.w;
    param = saturate(1 - param);

    // Draw nothing before the beginning of the deformation.
    if (param == 0) return;

    // Random selection: Draw nothing if not selected.
    uint seed = pid * 877;
    if (Random(seed) > _Density) return;

    // Additional parameter
    float param2 = dot(_EffectVector2.xyz, center) - _EffectVector2.w;
    param2 = saturate(1 - abs(0.5 - param2) * 2);

    // Gradient noise
    float3 npos = float3(Random(seed + 1) * 2378.34, _LocalTime * 0.8, 0);
    float4 snoise = snoise_grad(npos);

    // Scatter motion
    float ss_param = smoothstep(0, 1, param);
    float3 scatter = RandomVector(seed + 1);
    scatter *= (1 - ss_param) * _Scatter;

    // Cube position
    float3 pos = center - normal * _VoxelSize; // erode to compensate inflation
    pos += scatter + snoise.xyz * 0.01; // linear motion + undulation

    // Scale animation
    float3 scale = abs(snoise.xyz) * _VoxelSize * ss_param;
    scale.y *= 1 + smoothstep(0.0, 0.1, 1 - param);

    // Emission parameters
    half3 em = half3(saturate(param * 2), Random(seed + 2), param2);
    em.x *= 1 + smoothstep(0.0, 0.1, 1 - param);

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
    outStream.Append(VertexOutput(c_p2, c_n, float2(0, 0), em));
    outStream.Append(VertexOutput(c_p0, c_n, float2(1, 0), em));
    outStream.Append(VertexOutput(c_p6, c_n, float2(0, 1), em));
    outStream.Append(VertexOutput(c_p4, c_n, float2(1, 1), em));
    outStream.RestartStrip();

    c_n = float3(1, 0, 0);
    outStream.Append(VertexOutput(c_p1, c_n, float2(0, 0), em));
    outStream.Append(VertexOutput(c_p3, c_n, float2(1, 0), em));
    outStream.Append(VertexOutput(c_p5, c_n, float2(0, 1), em));
    outStream.Append(VertexOutput(c_p7, c_n, float2(1, 1), em));
    outStream.RestartStrip();

    c_n = float3(0, -1, 0);
    outStream.Append(VertexOutput(c_p0, c_n, float2(0, 0), em));
    outStream.Append(VertexOutput(c_p1, c_n, float2(1, 0), em));
    outStream.Append(VertexOutput(c_p4, c_n, float2(0, 1), em));
    outStream.Append(VertexOutput(c_p5, c_n, float2(1, 1), em));
    outStream.RestartStrip();

    c_n = float3(0, 1, 0);
    outStream.Append(VertexOutput(c_p3, c_n, float2(0, 0), em));
    outStream.Append(VertexOutput(c_p2, c_n, float2(1, 0), em));
    outStream.Append(VertexOutput(c_p7, c_n, float2(0, 1), em));
    outStream.Append(VertexOutput(c_p6, c_n, float2(1, 1), em));
    outStream.RestartStrip();

    c_n = float3(0, 0, -1);
    outStream.Append(VertexOutput(c_p1, c_n, float2(0, 0), em));
    outStream.Append(VertexOutput(c_p0, c_n, float2(1, 0), em));
    outStream.Append(VertexOutput(c_p3, c_n, float2(0, 1), em));
    outStream.Append(VertexOutput(c_p2, c_n, float2(1, 1), em));
    outStream.RestartStrip();

    c_n = float3(0, 0, 1);
    outStream.Append(VertexOutput(c_p4, c_n, float2(0, 0), em));
    outStream.Append(VertexOutput(c_p5, c_n, float2(1, 0), em));
    outStream.Append(VertexOutput(c_p6, c_n, float2(0, 1), em));
    outStream.Append(VertexOutput(c_p7, c_n, float2(1, 1), em));
    outStream.RestartStrip();
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
    half3 c_diff, c_spec;
    half not_in_use;

    c_diff = DiffuseAndSpecularFromMetallic(
        _Color.rgb, _Metallic, // input
        c_spec, not_in_use     // output
    );

    // Detect fixed-width edges with using screen space derivatives of
    // in-quad coodinates.
    float2 bcc = input.edge;
    float2 fw = fwidth(bcc);
    float2 edge2 = min(smoothstep(fw / 2, fw,     bcc),
                       smoothstep(fw / 2, fw, 1 - bcc));
    float edge = 1 - min(edge2.x, edge2.y);

    // Update the GBuffer.
    UnityStandardData data;
    data.diffuseColor = c_diff;
    data.occlusion = 1;
    data.specularColor = c_spec;
    data.smoothness = _Glossiness;
    data.normalWorld = input.normal;
    UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

    // Output ambient light to the emission buffer.
    half3 sh = ShadeSHPerPixel(data.normalWorld, input.ambient, input.wpos);
    outEmission = half4(sh * data.diffuseColor, 1);

    // Add emission colors.
    float3 em = input.emission;
    outEmission.xyz += lerp(_Emission1, _Emission2, em.y) * em.x;
    outEmission.xyz += _Emission3 * em.z;
    outEmission.xyz += lerp(_EdgeColor1, _EdgeColor2, em.y) * em.x * edge;
}

#endif
