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
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundColor(.accentColor)
            Text("Hello, world!")
            
            MTKViewContainer(renderer: renderer)
                .frame(width:  300.0,
                       height: 300.0)
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
