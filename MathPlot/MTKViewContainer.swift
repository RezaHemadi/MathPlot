//
//  MTKViewContainer.swift
//  MathPlot
//
//  Created by Reza on 5/14/23.
//

import Foundation
import SwiftUI
import MetalKit

struct MTKViewContainer: NSViewRepresentable {
    let renderer: Renderer
    
    func updateNSView(_ nsView: MTKView, context: Context) {
        
    }
    
    func makeNSView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColorMake(0.25, 0.25, 0.25, 1.0)
        mtkView.device = GPUDevice.shared
        renderer.view = mtkView
        mtkView.delegate = renderer
        
        return mtkView
    }
    
    class Coordinator: NSObject {
        var parent: MTKViewContainer
        
        init(_ container: MTKViewContainer) {
            self.parent = container
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
}

#if (canImport(UIKit))
import UIKit
struct MTKViewContainer: UIViewRepresentable {
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        
    }
    
    let renderer: Renderer
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.colorPixelFormat = .bgra8Unorm
        mtkView.clearColor = MTLClearColorMake(0.0, 1.0, 1.0, 1.0)
        mtkView.device = GPUDevice.shared
        renderer.view = mtkView
        mtkView.delegate = renderer
        
        return mtkView
    }
    
    class Coordinator: NSObject {
        var parent: MTKViewContainer
        
        init(_ container: MTKViewContainer) {
            self.parent = container
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
}
#endif
