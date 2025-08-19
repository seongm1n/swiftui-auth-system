//
//  auth_systemApp.swift
//  auth-system
//
//  Created by theo on 8/12/25.
//

import SwiftUI
import SwiftData

@main
struct auth_systemApp: App {
    // 인증 컨테이너 초기화
    private let authContainer = AuthContainer.shared
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.authContainer, authContainer)
        }
        .modelContainer(sharedModelContainer)
    }
}
