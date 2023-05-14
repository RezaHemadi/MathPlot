//
//  GPUDevice.swift
//  MathPlot
//
//  Created by Reza on 5/14/23.
//

import Foundation
import Metal

class GPUDevice {
    static var shared: MTLDevice = {
        return MTLCreateSystemDefaultDevice()!
    }()
}
