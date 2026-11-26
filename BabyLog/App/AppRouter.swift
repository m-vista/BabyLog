//
//  AppRouter.swift
//  BabyLog
//

import SwiftUI

/// Routes between Auth, Baby Setup, and Main Tabs based on session and membership state.
struct AppRouter: View {
    @Environment(AppEnvironment.self) private var environment
    @State private var babyLookup: BabyLookupState = .checking

    private enum BabyLookupState: Equatable {
        case checking
        case noBaby
        case hasBaby(BabyAccess)
        case failed(String)
    }

    var body: some View {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains(DeveloperLoggerDestination.launchArgument) {
            HomeView()
        } else {
            routedContent
        }
#else
        routedContent
#endif
    }

    @ViewBuilder
    private var routedContent: some View {
        switch environment.authService.sessionState {
        case .unknown:
            SplashView()
        case .signedOut:
            SignInView()
                .task {
                    environment.preferences.reset()
                }
        case .signedIn(let uid):
            Group {
                switch babyLookup {
                case .checking:
                    SplashView()
                case .noBaby:
                    BabySetupView(userID: uid) { access in
                        babyLookup = .hasBaby(access)
                    }
                case .hasBaby(let access):
                    MainTabView(access: access)
                case .failed(let message):
                    BabyLookupErrorView(message: message) {
                        await lookUpBaby(userID: uid)
                    }
                }
            }
            .task(id: uid) {
                await lookUpBaby(userID: uid)
            }
            .task(id: uid) {
                try? await environment.preferences.load(userID: uid)
            }
        }
    }

    @MainActor
    private func lookUpBaby(userID: String) async {
        babyLookup = .checking
        do {
            let accesses = try await environment.babyRepository.babyAccesses(for: userID)
            babyLookup = accesses.first.map(BabyLookupState.hasBaby) ?? .noBaby
        } catch {
            babyLookup = .failed(BabyErrorPresenter.message(for: error))
        }
    }
}

private struct BabyLookupErrorView: View {
    let message: String
    let retry: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Couldn’t Load Baby", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task { await retry() }
            }
        }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            BabyLogTheme.cream.ignoresSafeArea()
            ProgressView()
        }
    }
}

#Preview {
    AppRouter()
        .environment(AppEnvironment())
}
