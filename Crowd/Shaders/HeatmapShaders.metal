//
//  HeatmapShaders.metal
//  Crowd
//
//  GPU-accelerated heatmap shaders for smooth crowd visualization
//

#include <metal_stdlib>
using namespace metal;

// Gaussian falloff function
float gaussian(float distance, float radius) {
    float sigma = radius / 3.0;
    return exp(-(distance * distance) / (2.0 * sigma * sigma));
}

// Kernel 1: Render intensity map with Gaussian falloff
kernel void heatmap_intensity_kernel(
    texture2d<float, access::write> outTexture [[texture(0)]],
    constant int32_t& pointCount [[buffer(0)]],
    constant float2* points [[buffer(1)]],
    constant float* intensities [[buffer(2)]],
    constant float& radius [[buffer(3)]],
    uint2 gid [[thread_position_in_grid]]
) {
    float2 pixelPos = float2(gid.x, gid.y);
    float totalIntensity = 0.0;
    
    // Accumulate intensity from all points
    for (int i = 0; i < pointCount; i++) {
        float2 point = points[i];
        float intensity = intensities[i];
        
        float dist = distance(pixelPos, point);
        
        if (dist < radius * 3.0) { // Only compute within 3 sigma
            float contribution = gaussian(dist, radius) * intensity;
            totalIntensity += contribution;
        }
    }
    
    // Write grayscale intensity
    outTexture.write(float4(totalIntensity, 0.0, 0.0, 1.0), gid);
}

// Heat gradient color lookup
float4 heatmapColor(float intensity) {
    // Clamp intensity to [0, 1]
    intensity = clamp(intensity, 0.0, 1.0);
    
    // Multi-stop gradient: transparent -> blue -> cyan -> green -> yellow -> orange -> red
    if (intensity < 0.01) {
        return float4(0.0, 0.0, 0.0, 0.0); // Fully transparent
    } else if (intensity < 0.2) {
        // Blue to cyan
        float t = (intensity - 0.01) / 0.19;
        float3 color = mix(float3(0.0, 0.0, 1.0), float3(0.0, 1.0, 1.0), t);
        float alpha = mix(0.3, 0.5, t);
        return float4(color, alpha);
    } else if (intensity < 0.4) {
        // Cyan to green
        float t = (intensity - 0.2) / 0.2;
        float3 color = mix(float3(0.0, 1.0, 1.0), float3(0.0, 1.0, 0.0), t);
        float alpha = mix(0.5, 0.65, t);
        return float4(color, alpha);
    } else if (intensity < 0.6) {
        // Green to yellow
        float t = (intensity - 0.4) / 0.2;
        float3 color = mix(float3(0.0, 1.0, 0.0), float3(1.0, 1.0, 0.0), t);
        float alpha = mix(0.65, 0.75, t);
        return float4(color, alpha);
    } else if (intensity < 0.8) {
        // Yellow to orange
        float t = (intensity - 0.6) / 0.2;
        float3 color = mix(float3(1.0, 1.0, 0.0), float3(1.0, 0.5, 0.0), t);
        float alpha = mix(0.75, 0.85, t);
        return float4(color, alpha);
    } else {
        // Orange to red
        float t = (intensity - 0.8) / 0.2;
        float3 color = mix(float3(1.0, 0.5, 0.0), float3(1.0, 0.0, 0.0), t);
        float alpha = mix(0.85, 0.95, t);
        return float4(color, alpha);
    }
}

// Kernel 2: Apply color gradient to intensity map
kernel void heatmap_colormap_kernel(
    texture2d<float, access::read> intensityTexture [[texture(0)]],
    texture2d<float, access::write> colorTexture [[texture(1)]],
    uint2 gid [[thread_position_in_grid]]
) {
    // Read intensity value
    float intensity = intensityTexture.read(gid).r;
    
    // Apply color gradient
    float4 color = heatmapColor(intensity);
    
    // Write colored output
    colorTexture.write(color, gid);
}

