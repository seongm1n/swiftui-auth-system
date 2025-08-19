//
//  ContentView.swift
//  auth-system
//
//  Created by theo on 8/12/25.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.authContainer) private var authContainer
    
    var body: some View {
        Group {
            if authContainer.isAuthenticated {
                ProfileView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut, value: authContainer.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
