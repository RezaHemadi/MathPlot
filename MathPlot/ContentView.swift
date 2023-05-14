//
//  ContentView.swift
//  MathPlot
//
//  Created by Reza on 5/14/23.
//

import SwiftUI

struct ContentView: View {
    @State var renderer = Renderer()
    
    var body: some View {
        VStack {
            Text("Curve Plotter")
            MTKViewContainer(renderer: renderer)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
