//
//  Renderer.swift
//  MathPlot
//
//  Created by Reza on 5/14/23.
//

import Foundation
import MetalKit
import Matrix
import os.signpost

let kMaxBuffersInFlight = 3

enum RendererError: Error {
    case library
    case commandQueue
    
    var description: String {
        switch self {
        case .library:
            return "failed to initialize metal library"
        case .commandQueue:
            return "failed to initialize command queue"
        }
    }
}

class Renderer: NSObject, MTKViewDelegate {
    // MARK: - Properties
    var view: MTKView! {
        didSet {
            guard view != nil else { return }
            do {
                try loadMetal()
            } catch {
                os_log(.error, "\(error.localizedDescription)")
            }
        }
    }
    var commandQueue: MTLCommandQueue!
    var renderState: MTLRenderPipelineState!
    var _inFlightSemaphore = DispatchSemaphore(value: kMaxBuffersInFlight)
    
    var axisVBuffer: MTLBuffer!
    var axisIndexBuffer: MTLBuffer!
    var axisVBufferOffset: Int = 0
    
    var dynamicBufferIndex: Int = 0
    
    var axisVertices: Mat<Float>
    var axisIndices: Vec<UInt32>
    var axisVBufferAddress: UnsafeMutableRawPointer!
    
    var curveVertices: Mat<Float>
    var curveIndices: Vec<UInt32>
    var curveVBuffer: MTLBuffer!
    var curveIndexBuffer: MTLBuffer!
    var curveVBufferOffset: Int = 0
    var curveVBufferAddress: UnsafeMutableRawPointer!
    
    
    // MARK: - Initialization
    override init() {
        let device = GPUDevice.shared
        
        // Initialize axis vertices and indices
        axisVertices = .init(4, 2)
        axisIndices = .init([0, 1, 2, 3])
        axisVertices.row(0) <<== [-1.0, 0.0]
        axisVertices.row(1) <<== [1.0, 0.0]
        axisVertices.row(2) <<== [0.0, -1.0]
        axisVertices.row(3) <<== [0.0, 1.0]
        
        // Initialize curve vertices and indices
        curveVertices = .init([0.0, 0.5, 1.0, 0.5], [2, 2])
        curveIndices = .init([0, 1])
        
        // initialize axis buffers
        axisVBuffer = device.makeBuffer(length: MemoryLayout<Float>.size * 2 * 4 * kMaxBuffersInFlight)
        axisVBufferAddress = axisVBuffer.contents()
        axisIndexBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size * axisIndices.count)
        axisIndexBuffer.contents().assumingMemoryBound(to: UInt32.self).initialize(from: axisIndices.valuesPtr.pointer, count: 4)
        
        // initialize curve buffers
        curveVBuffer = device.makeBuffer(length: MemoryLayout<Float>.size * curveVertices.size.count * kMaxBuffersInFlight)
        curveIndexBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size * curveIndices.count)
        curveIndexBuffer.contents().assumingMemoryBound(to: UInt32.self).initialize(from: curveIndices.valuesPtr.pointer, count: curveIndices.count)
        
        super.init()
    }
    
    // MARK: - Helper Methods
    func loadMetal() throws {
        let device = GPUDevice.shared
        
        // configure vertex descriptor
        let vertexDescriptor = MTLVertexDescriptor()
        // position
        vertexDescriptor.attributes[0].format = .float2
        vertexDescriptor.attributes[0].offset = 0
        vertexDescriptor.attributes[0].bufferIndex = 0
        
        // buffer layouts
        vertexDescriptor.layouts[0].stride = MemoryLayout<Float>.size * 2
        
        // initialize vertex and fragment shaders
        guard let library = device.makeDefaultLibrary() else { os_log(.error, "failed to initialize metal function library"); throw RendererError.library }
        
        let vertexShader = library.makeFunction(name: "vertexShader")
        let fragmentShader = library.makeFunction(name: "fragmentShader")
        
        // initialize render pipeline
        let renderDescriptor = MTLRenderPipelineDescriptor()
        renderDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
        renderDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
        renderDescriptor.stencilAttachmentPixelFormat = view.depthStencilPixelFormat
        renderDescriptor.vertexFunction = vertexShader
        renderDescriptor.fragmentFunction = fragmentShader
        renderDescriptor.vertexDescriptor = vertexDescriptor
        
        renderState = try device.makeRenderPipelineState(descriptor: renderDescriptor)
        
        guard let commandQueue = device.makeCommandQueue() else { throw RendererError.commandQueue }
        
        self.commandQueue = commandQueue
    }
    
    func updateDynamicBuffers() {
        dynamicBufferIndex = (dynamicBufferIndex + 1) % kMaxBuffersInFlight
        
        axisVBufferOffset = MemoryLayout<Float>.size * 2 * 4 * dynamicBufferIndex
        curveVBufferOffset = MemoryLayout<Float>.size * curveVertices.size.count * dynamicBufferIndex
        
        axisVBufferAddress = axisVBuffer.contents().advanced(by: axisVBufferOffset)
        curveVBufferAddress = curveVBuffer.contents().advanced(by: curveVBufferOffset)
    }
    
    func updateAppState() {
        axisVBufferAddress.assumingMemoryBound(to: Float.self).initialize(from: axisVertices.valuesPtr.pointer, count: axisVertices.size.count)
        curveVBufferAddress.assumingMemoryBound(to: Float.self).initialize(from: curveVertices.valuesPtr.pointer, count: curveVertices.size.count)
    }
    
    // MARK: - MTKViewDelegate
    func draw(in view: MTKView) {
        let _ = _inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        if let commandBuffer = commandQueue.makeCommandBuffer() {
            let semaphore = _inFlightSemaphore
            commandBuffer.addCompletedHandler { _ in
                semaphore.signal()
            }
            
            updateDynamicBuffers()
            updateAppState()
            
            if let renderPassDescriptor = view.currentRenderPassDescriptor, let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) {
                // Draw Axis lines
                renderEncoder.setRenderPipelineState(renderState)
                renderEncoder.setVertexBuffer(axisVBuffer, offset: axisVBufferOffset, index: 0)
                renderEncoder.drawIndexedPrimitives(type: .line, indexCount: axisIndices.count, indexType: .uint32, indexBuffer: axisIndexBuffer, indexBufferOffset: 0)
                
                // Draw curve
                renderEncoder.setVertexBuffer(curveVBuffer, offset: curveVBufferOffset, index: 0)
                renderEncoder.drawIndexedPrimitives(type: .line, indexCount: curveIndices.count, indexType: .uint32, indexBuffer: curveIndexBuffer, indexBufferOffset: 0)
                
                
                renderEncoder.endEncoding()
                
                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
                commandBuffer.commit()
            }
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        
    }
}
