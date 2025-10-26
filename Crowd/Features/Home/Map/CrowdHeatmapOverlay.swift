//
//  CrowdHeatmapOverlay.swift
//  Crowd
//
//  Created by Teni Owojori on 10/19/25.
//

import SwiftUI
import MapKit
import Metal
import MetalKit

struct HeatmapPoint: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let intensity: Double // 0.0 to 1.0
}

struct CrowdHeatmapOverlay: View {
    let events: [CrowdEvent]
    let mapRegion: MKCoordinateRegion
    
    var heatmapPoints: [HeatmapPoint] {
        events.map { event in
            // Calculate intensity based on attendance
            let normalizedIntensity = min(Double(event.attendeeCount) / 40.0, 1.0)
            return HeatmapPoint(
                coordinate: event.coordinates,
                intensity: max(0.4, normalizedIntensity)
            )
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            MetalHeatmapView(
                points: heatmapPoints,
                mapRegion: mapRegion,
                geometry: geometry
            )
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Metal Heatmap View
struct MetalHeatmapView: UIViewRepresentable {
    let points: [HeatmapPoint]
    let mapRegion: MKCoordinateRegion
    let geometry: GeometryProxy
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.delegate = context.coordinator
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = true
        mtkView.framebufferOnly = false
        mtkView.backgroundColor = .clear
        mtkView.isOpaque = false
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        context.coordinator.points = points
        context.coordinator.mapRegion = mapRegion
        context.coordinator.geometry = geometry
        uiView.setNeedsDisplay()
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(points: points, mapRegion: mapRegion, geometry: geometry)
    }
    
    class Coordinator: NSObject, MTKViewDelegate {
        var points: [HeatmapPoint]
        var mapRegion: MKCoordinateRegion
        var geometry: GeometryProxy
        
        private var device: MTLDevice!
        private var commandQueue: MTLCommandQueue!
        private var pipelineState: MTLComputePipelineState!
        private var colorMapPipelineState: MTLComputePipelineState!
        
        init(points: [HeatmapPoint], mapRegion: MKCoordinateRegion, geometry: GeometryProxy) {
            self.points = points
            self.mapRegion = mapRegion
            self.geometry = geometry
            super.init()
            setupMetal()
        }
        
        private func setupMetal() {
            guard let device = MTLCreateSystemDefaultDevice() else {
                print("Metal not supported")
                return
            }
            self.device = device
            self.commandQueue = device.makeCommandQueue()
            
            // Create Metal library and pipeline states
            let library = device.makeDefaultLibrary()
            
            // Intensity rendering kernel
            if let intensityFunction = library?.makeFunction(name: "heatmap_intensity_kernel") {
                pipelineState = try? device.makeComputePipelineState(function: intensityFunction)
            }
            
            // Color mapping kernel
            if let colorMapFunction = library?.makeFunction(name: "heatmap_colormap_kernel") {
                colorMapPipelineState = try? device.makeComputePipelineState(function: colorMapFunction)
            }
        }
        
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
        
        func draw(in view: MTKView) {
            guard let drawable = view.currentDrawable,
                  let device = view.device,
                  let commandBuffer = commandQueue?.makeCommandBuffer(),
                  let pipelineState = pipelineState,
                  let colorMapPipelineState = colorMapPipelineState else {
                return
            }
            
            let width = Int(view.drawableSize.width)
            let height = Int(view.drawableSize.height)
            
            // Create intensity texture (grayscale)
            let intensityDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .r32Float,
                width: width,
                height: height,
                mipmapped: false
            )
            intensityDescriptor.usage = [.shaderRead, .shaderWrite]
            guard let intensityTexture = device.makeTexture(descriptor: intensityDescriptor) else { return }
            
            // Create final color texture
            let colorDescriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            colorDescriptor.usage = [.shaderRead, .shaderWrite]
            guard let colorTexture = device.makeTexture(descriptor: colorDescriptor) else { return }
            
            // Step 1: Render intensity map
            if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                computeEncoder.setComputePipelineState(pipelineState)
                computeEncoder.setTexture(intensityTexture, index: 0)
                
                // Convert points to screen space
                var screenPoints: [SIMD2<Float>] = []
                var intensities: [Float] = []
                
                for point in points {
                    if let screenPoint = coordinateToPoint(point.coordinate, region: mapRegion, size: CGSize(width: width, height: height)) {
                        screenPoints.append(SIMD2<Float>(Float(screenPoint.x), Float(screenPoint.y)))
                        intensities.append(Float(point.intensity))
                    }
                }
                
                // Pass data to shader
                var pointCount = Int32(screenPoints.count)
                var pointsData = screenPoints
                var intensitiesData = intensities
                var radius = Float(80.0) // Gaussian radius
                
                computeEncoder.setBytes(&pointCount, length: MemoryLayout<Int32>.size, index: 0)
                computeEncoder.setBytes(&pointsData, length: screenPoints.count * MemoryLayout<SIMD2<Float>>.size, index: 1)
                computeEncoder.setBytes(&intensitiesData, length: intensities.count * MemoryLayout<Float>.size, index: 2)
                computeEncoder.setBytes(&radius, length: MemoryLayout<Float>.size, index: 3)
                
                let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
                let threadGroups = MTLSize(
                    width: (width + threadGroupSize.width - 1) / threadGroupSize.width,
                    height: (height + threadGroupSize.height - 1) / threadGroupSize.height,
                    depth: 1
                )
                
                computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                computeEncoder.endEncoding()
            }
            
            // Step 2: Apply color gradient
            if let computeEncoder = commandBuffer.makeComputeCommandEncoder() {
                computeEncoder.setComputePipelineState(colorMapPipelineState)
                computeEncoder.setTexture(intensityTexture, index: 0)
                computeEncoder.setTexture(colorTexture, index: 1)
                
                let threadGroupSize = MTLSize(width: 8, height: 8, depth: 1)
                let threadGroups = MTLSize(
                    width: (width + threadGroupSize.width - 1) / threadGroupSize.width,
                    height: (height + threadGroupSize.height - 1) / threadGroupSize.height,
                    depth: 1
                )
                
                computeEncoder.dispatchThreadgroups(threadGroups, threadsPerThreadgroup: threadGroupSize)
                computeEncoder.endEncoding()
            }
            
            // Step 3: Blit to drawable
            if let blitEncoder = commandBuffer.makeBlitCommandEncoder() {
                blitEncoder.copy(
                    from: colorTexture,
                    sourceSlice: 0,
                    sourceLevel: 0,
                    sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                    sourceSize: MTLSize(width: width, height: height, depth: 1),
                    to: drawable.texture,
                    destinationSlice: 0,
                    destinationLevel: 0,
                    destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
                )
                blitEncoder.endEncoding()
            }
            
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
        
        private func coordinateToPoint(_ coordinate: CLLocationCoordinate2D, region: MKCoordinateRegion, size: CGSize) -> CGPoint? {
            let latSpan = region.span.latitudeDelta
            let lonSpan = region.span.longitudeDelta
            
            let latOffset = (coordinate.latitude - region.center.latitude) / latSpan
            let lonOffset = (coordinate.longitude - region.center.longitude) / lonSpan
            
            let x = size.width * (0.5 + lonOffset)
            let y = size.height * (0.5 - latOffset)
            
            guard x >= -200 && x <= size.width + 200 && y >= -200 && y <= size.height + 200 else {
                return nil
            }
            
            return CGPoint(x: x, y: y)
        }
    }
}

#Preview {
    CrowdHeatmapOverlay(
        events: [
            CrowdEvent(
                id: "1",
                title: "Basketball",
                hostId: "h1",
                hostName: "Host 1",
                latitude: 33.2105,
                longitude: -97.1520,
                radiusMeters: 60,
                startsAt: Date(),
                endsAt: Date().addingTimeInterval(3600),
                createdAt: Date(),
                signalStrength: 4,
                attendeeCount: 45,
                tags: [],
                category: "sports"
            ),
            CrowdEvent(
                id: "2",
                title: "Party",
                hostId: "h2",
                hostName: "Host 2",
                latitude: 33.2108,
                longitude: -97.1522,
                radiusMeters: 60,
                startsAt: Date(),
                endsAt: Date().addingTimeInterval(3600),
                createdAt: Date(),
                signalStrength: 5,
                attendeeCount: 60,
                tags: [],
                category: "party"
            ),
            CrowdEvent(
                id: "3",
                title: "Study",
                hostId: "h3",
                hostName: "Host 3",
                latitude: 33.2110,
                longitude: -97.1518,
                radiusMeters: 60,
                startsAt: Date(),
                endsAt: Date().addingTimeInterval(3600),
                createdAt: Date(),
                signalStrength: 3,
                attendeeCount: 15,
                tags: [],
                category: "study"
            )
        ],
        mapRegion: MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 33.2105, longitude: -97.1520),
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
    )
    .frame(width: 400, height: 400)
    .background(Color.gray.opacity(0.3))
}
