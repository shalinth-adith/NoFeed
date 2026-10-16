//
//  RootContainerView.swift
//  NoFeed
//
//  Shows onboarding on first launch, then the main tab bar. The completion flag
//  lives in the App Group so it persists.
//

import SwiftUI

struct RootContainerView: View {
    @AppStorage("hasCompletedOnboarding", store: AppGroup.defaults)
    private var hasCompletedOnboarding = false

    private let health = StoreHealth.shared

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                RootView()
            } else {
                OnboardingView { hasCompletedOnboarding = true }
            }
        }
        // Over everything, including the session cover, because a session
        // that won't be recorded is exactly when someone needs to know.
        .overlay(alignment: .top) {
            if let problem = health.problem {
                StoreProblemBanner(problem: problem) { health.acknowledge() }
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(ZTheme.Motion.smooth, value: health.problem)
    }
}
