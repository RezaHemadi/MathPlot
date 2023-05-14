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
let kMaxVertices = 10_000

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
    
    var vertices: Mat<Float>
    var indices: Vec<UInt32>
    var vertexBuffer: MTLBuffer!
    var indexBuffer: MTLBuffer!
    var vertexBufferAddress: UnsafeMutableRawPointer!
    var vertexBufferOffset: Int = 0
    var dynamicBufferIndex: Int = 0
    var vertexCount: Int = 4
    
    // MARK: - Initialization
    override init() {
        let device = GPUDevice.shared
        
        vertices = .init(vertexCount, 2)
        indices = .init([0, 1, 2, 3])
        
        vertices.row(0) <<== [-1.0, 0.0]
        vertices.row(1) <<== [1.0, 0.0]
        vertices.row(2) <<== [0.0, -1.0]
        vertices.row(3) <<== [0.0, 1.0]
        
        // initialize buffers
        vertexBuffer = device.makeBuffer(length: MemoryLayout<Float>.size * 2 * kMaxVertices * kMaxBuffersInFlight)
        vertexBufferAddress = vertexBuffer.contents()
        indexBuffer = device.makeBuffer(length: MemoryLayout<UInt32>.size * 10)
        indexBuffer.contents().assumingMemoryBound(to: UInt32.self).initialize(from: indices.valuesPtr.pointer, count: 10)
        
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
        
        vertexBufferOffset = MemoryLayout<Float>.size * 2 * kMaxVertices * dynamicBufferIndex
        vertexBufferAddress = vertexBuffer.contents().advanced(by: vertexBufferOffset)
    }
    
    func updateAppState() {
        vertexBufferAddress.assumingMemoryBound(to: Float.self).initialize(from: vertices.valuesPtr.pointer, count: vertices.size.count)
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
                renderEncoder.setRenderPipelineState(renderState)
                renderEncoder.setVertexBuffer(vertexBuffer, offset: vertexBufferOffset, index: 0)
                renderEncoder.drawIndexedPrimitives(type: .line, indexCount: vertexCount, indexType: .uint32, indexBuffer: indexBuffer, indexBufferOffset: 0)
                
                renderEncoder.endEncoding()
                
                if let drawable = view.currentDrawable {
                    commandBuffer.present(drawable)
                }
                commandBuffer.commit()
            }
        }
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        os_log(.info, "drawable size changed")
    }
}
