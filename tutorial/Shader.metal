#include <metal_stdlib>
using namespace metal;


vertex float4 vertex_shader(const device float3 *vertices [[ buffer(0) ]], uint vertexId [[ vertex_id ]]) {
    return float4(vertices[vertexId], 1.0);
}

fragment half4 fragment_shader() {
    return half4(1.0, 0.0, 0.0, 1.0);
}
