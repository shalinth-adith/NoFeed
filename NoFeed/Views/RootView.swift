//
//  RootView.swift
//  NoFeed
//
//  Tab bar hosting the main surface: Focus (Home), Insights, Profiles,
//  Schedules, and Settings.
//
//  We use the NATIVE TabView tab bar rather than a hand-built one. On iOS 26 the
//  system bar renders in real Liquid Glass automatically — with the adaptive
//  luminosity, scroll-edge vibrancy and morphing selection indicator that a
//  custom `.glassEffect` shape on a dark background can't reproduce. Using the
//  system control (and only it) is also what removed the earlier doubled bar:
//  there's exactly one bar, owned by TabView.
//

import SwiftUI

extension Notification.Name {
    /// Posted by screens that want to land the user on the Focus tab (e.g. the
    /// Insights first-run "Begin your first focus" call).
    static let noFeedOpenFocus = Notification.Name("noFeedOpenFocus")

    /// Posted when the weekly recap notification is tapped. Handled here rather
    /// than on a tab for the same reason the session cover is (see below): the
    /// tap can arrive with any tab selected.
    static let noFeedOpenRecap = Notification.Name("noFeedOpenRecap")
}

struct RootView: View {
    @Environment(FocusSessionController.self) private var session
    @State private var selection = 0
    @State private var showingRecap = false

    /// The running session covers the whole app, not just the Focus tab.
    ///
    /// It used to be a `fullScreenCover` on `HomeView`, and that is a tab — so a
    /// session started from anywhere else (the profile editor's "Start a …
    /// session", two sheets deep on Settings) asked a BACKGROUND tab to present.
    /// SwiftUI drops that presentation but keeps the binding true, so it then
    /// believes the cover is already up and never acts again: a session running
    /// with no timer, no pause and no way to end it. Presenting from the TabView
    /// itself takes tab visibility out of the question entirely.
    private var isShowingSession: Binding<Bool> {
        Binding(
            get: { session.hasScreenToShow && !session.isMinimized },
            set: { $0 ? session.surface() : session.minimize() }
        )
    }

    var body: some View {
        // Four tabs, matching the Quiet comp: Focus · Insights · Schedule ·
        // Settings. Profiles are switched from the row on the Focus screen and
        // managed from Settings, so they're no longer a tab.
        TabView(selection: $selection) {
            HomeView()
                .tabItem { Label("Focus", systemImage: "circle.circle") }
                .tag(0)
            AnalyticsView()
                .tabItem { Label("Insights", systemImage: "chart.bar") }
                .tag(1)
            SchedulesView()
                .tabItem { Label("Schedule", systemImage: "calendar") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "sun.max") }
                .tag(3)
        }
        // Quiet chrome: the selected tab reads primary-white, not a chromatic
        // accent. Unselected items stay system-grey, so selection is still clear.
        .tint(ZTheme.Palette.textPrimary)
        .onReceive(NotificationCenter.default.publisher(for: .noFeedOpenFocus)) { _ in
            selection = 0
            // Held back, then released, and the wait is the point.
            //
            // This arrives while the sheet the session was started from is still
            // dismissing, and UIKit will not present over a sheet chain that is
            // still up — the attempt is simply dropped. Nothing then re-presents
            // it: `@Observable` only re-renders this view for what it reads, and
            // it does not read the per-second countdown, so the binding is not
            // re-evaluated until some unrelated change happens to come along.
            // That is how a session took ten seconds to show its face.
            //
            // Tucking it away first also guarantees a real false → true edge,
            // rather than setting a value SwiftUI has already seen.
            session.minimize()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                session.surface()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .noFeedOpenRecap)) { _ in
            // Never over a running session. The cover on this same view is
            // already presenting, and stacking a sheet on it is the flaky case;
            // more to the point, pulling someone out of the session they are in
            // to show them last week's numbers is the wrong trade. The recap
            // keeps: it stays reachable from the row on Insights.
            guard !session.hasScreenToShow else { return }
            showingRecap = true
        }
        .sheet(isPresented: $showingRecap) { WeeklyRecapView() }
        .fullScreenCover(isPresented: isShowingSession) {
            switch session.phase {
            case .focus, .breakTime: SessionView(onMinimize: { session.minimize() })
            case .summary: SessionSummaryView()
            case .idle: Color.clear
            }
        }
    }
}
