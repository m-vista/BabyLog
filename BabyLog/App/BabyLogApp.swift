//
//  BabyLogApp.swift
//  BabyLog
//

import SwiftUI
import FirebaseCore
import FirebaseFirestore

@main
struct BabyLogApp: App {
    // Assigned in init(), after FirebaseApp.configure(), since AppEnvironment's
    // services (AuthService) touch Auth.auth() at construction time.
    private let environment: AppEnvironment

    init() {
        FirebaseApp.configure()

        let settings = Firestore.firestore().settings
        settings.cacheSettings = PersistentCacheSettings()
        Firestore.firestore().settings = settings

        environment = AppEnvironment()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(environment)
                .dynamicTypeSize(.medium...DynamicTypeSize.accessibility5)
                .preferredColorScheme(colorScheme)
        }
    }

    private var colorScheme: ColorScheme? {
        switch environment.preferences.values.appearanceMode {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
