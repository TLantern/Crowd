# GPU-Accelerated Heatmap Implementation

## Overview
This implementation uses Metal compute shaders to render smooth, professional-quality heatmaps with continuous color gradients and Gaussian falloff.

## Architecture

### 1. **CrowdHeatmapOverlay.swift**
SwiftUI view that coordinates the heatmap rendering.

- Converts `CrowdEvent` data into `HeatmapPoint` structures
- Manages `MTKView` through `UIViewRepresentable`
- Handles coordinate-to-screen conversion for MapKit integration

### 2. **MetalHeatmapView**
UIViewRepresentable wrapper that manages the Metal rendering pipeline.

**Pipeline Steps:**
1. **Intensity Rendering** - Creates grayscale intensity map
2. **Color Mapping** - Applies heat gradient to intensity values
3. **Blitting** - Copies final texture to drawable

### 3. **HeatmapShaders.metal**
Contains two compute kernels:

#### a. `heatmap_intensity_kernel`
- Renders Gaussian falloff for each event point
- Accumulates intensity values additively
- Output: Single-channel float texture (grayscale)

**Gaussian Function:**
```
intensity = exp(-(distance²) / (2σ²))
where σ = radius / 3
```

#### b. `heatmap_colormap_kernel`
- Reads intensity texture
- Maps intensity to heat gradient colors
- Output: RGBA color texture with transparency

## Color Gradient

The heat gradient uses 6 stops for smooth transitions:

| Intensity | Color      | Alpha | Meaning          |
|-----------|------------|-------|------------------|
| 0.00-0.01 | Clear      | 0.0   | No activity      |
| 0.01-0.20 | Blue-Cyan  | 0.3-0.5| Low activity    |
| 0.20-0.40 | Cyan-Green | 0.5-0.65| Moderate       |
| 0.40-0.60 | Green-Yellow| 0.65-0.75| Active         |
| 0.60-0.80 | Yellow-Orange| 0.75-0.85| Very active   |
| 0.80-1.00 | Orange-Red | 0.85-0.95| Extremely hot  |

## Performance Characteristics

### GPU Advantages:
- ✅ Parallel processing of all pixels
- ✅ Hardware-accelerated texture operations
- ✅ Smooth 60 FPS rendering
- ✅ No CPU bottleneck for large datasets

### Optimization:
- 3σ cutoff (99.7% of Gaussian distribution)
- Thread group size: 8×8 for optimal GPU utilization
- R32Float for intensity (single-channel)
- BGRA8Unorm for final color (standard format)

## Integration with MapKit

The heatmap overlays on top of the `Map` view using coordinate transformation:

```swift
let latOffset = (coordinate.latitude - region.center.latitude) / latSpan
let lonOffset = (coordinate.longitude - region.center.longitude) / lonSpan

let x = size.width * (0.5 + lonOffset)
let y = size.height * (0.5 - latOffset) // Inverted Y
```

## Adding the .metal File to Xcode

**Important:** Make sure `HeatmapShaders.metal` is added to your Xcode project:

1. In Xcode, right-click on the `Shaders` folder
2. Select "Add Files to Crowd..."
3. Choose `HeatmapShaders.metal`
4. Ensure "Target Membership" includes your app target
5. Build Phases → "Compile Sources" should list the .metal file

## Customization

### Adjust Heatmap Radius:
In `CrowdHeatmapOverlay.swift`, line ~149:
```swift
var radius = Float(80.0) // Increase for wider spread
```

### Modify Color Gradient:
In `HeatmapShaders.metal`, function `heatmapColor()`:
- Adjust intensity thresholds
- Change RGB color values
- Modify alpha values for transparency

### Change Intensity Calculation:
In `CrowdHeatmapOverlay.swift`, `heatmapPoints`:
```swift
let normalizedIntensity = min(Double(event.attendeeCount) / 40.0, 1.0)
```

## Troubleshooting

### "Metal not supported"
- Check that the device has Metal capability (all iOS devices since A7 chip)

### Shader compilation errors:
- Verify `HeatmapShaders.metal` is in Build Phases → Compile Sources
- Check Metal syntax in Xcode (warnings/errors will show)

### Performance issues:
- Reduce radius value
- Lower the 3σ cutoff multiplier
- Optimize thread group sizes

## References

- [Apple Metal Programming Guide](https://developer.apple.com/metal/)
- [Metal Shading Language Specification](https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf)
- [Metal Performance Shaders](https://developer.apple.com/documentation/metalperformanceshaders)

