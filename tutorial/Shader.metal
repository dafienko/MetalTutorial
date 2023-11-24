#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 projectionMatrix;
};

struct VertexIn {
    float3 position [[ attribute(0) ]];
    float3 normal [[ attribute(1) ]];
};

struct VertexOut {
    float4 position [[ position ]];
    float3 normal;
};

vertex VertexOut vertex_shader(const VertexIn vertexIn [[ stage_in ]], constant Uniforms &uniforms [[ buffer(1) ]]) {
    VertexOut vertexOut = { 0 };
    
    vertexOut.position = uniforms.projectionMatrix * uniforms.modelMatrix * float4(vertexIn.position, 1.0);
    vertexOut.normal = vertexIn.normal;
    
    return vertexOut;
}

fragment half4 fragment_shader(const VertexOut vertexFragment [[ stage_in ]]) {
    return half4(1.0, 0.0, 0.0, 1.0);
}
