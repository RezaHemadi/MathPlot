//
//  Shaders.metal
//  MathPlot
//
//  Created by Reza on 5/14/23.
//

#include <metal_stdlib>
using namespace metal;


typedef struct {
    float3 position [[ attribute(0) ]];
} Vertex;

typedef struct {
    float4 position [[ position ]];
} ColorInOut;

ColorInOut vertex vertexShader(Vertex in [[ stage_in ]])
{
    ColorInOut out;
    float4 position = float4(in.position, 1.0);
    
    out.position = position;
    
    return out;
}

float4 fragment fragmentShader(ColorInOut in [[ stage_in ]])
{
    return float4(1.0, 0.0, 0.0, 1.0);
}
