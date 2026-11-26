//
//  ContentView.swift
//  BabyLog
//
//  Created by Mohana Vista on 9/29/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        AppRouter()
    }
}

#Preview {
    ContentView()
        .environment(AppEnvironment())
}
