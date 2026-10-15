//
//  NoFeedApp.swift
//  NoFeed
//
//  Composition root. Creates the shared @Observable controllers once and
//  injects them into the environment. Refreshes the active session's countdown
//  whenever the app returns to the foreground (drift-free resync).
//

import SwiftUI

@main
struct NoFeedApp: App {
    @State private var authorization = AuthorizationService()
    @State private var profiles = ProfileStore()
    @State private var schedules = ScheduleStore()
    @State private var session = FocusSessionController()
    @State private var suggestions = SmartSuggestionService()
    @State private var analytics = AnalyticsService()
    @State private var achievements = AchievementService()
    @State private var challenges = ChallengeService()
    @State private var accountability = AccountabilityService()

    @Environment(\.scenePhase) private var scenePhase

    init() {
        BackgroundRefresh.register()
        // Install the notification delegate before anything schedules or
        // delivers — otherwise foreground notifications are silently dropped.
        NotificationService.shared.activate()
        #if DEBUG
        // Before anything reads it — `FocusSessionController.restoreIfNeeded`
        // runs on the first `.active` and would bring a test's leftover session
        // straight back.
        DebugSeed.clearSessionIfRequested()
        DebugSeed.resetOnboardingIfRequested()
        DebugSeed.completeOnboardingIfRequested()
        DebugSeed.skipNotificationRationaleIfTesting()
        MainActor.assumeIsolated {
            DebugSeed.clearHistoryIfRequested()
            DebugSeed.clearSchedulesIfRequested()
            DebugSeed.seedDemoHistoryIfRequested()
            DebugSeed.seedManyProfilesIfRequested()
            // Stored-property initializers run before this body, so `profiles`
            // has already fetched by the time the seed inserts anything. The
            // history seed doesn't care — Insights queries on demand — but the
            // profile list is held in memory and would simply not show them.
            profiles.fetch()
            if DebugSeed.wantsProfileReset { profiles.resetToDefaultsForUITests() }
            // Same reason for the schedule list after a UI-test reset.
            schedules.fetch()
        }
        DebugSeed.primeShieldPreviewSession()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if let subject = DebugSeed.blockScreenPreviewSubject {
                // Screen 03 — the block screen. iOS draws the real one and
                // Simulator cannot raise a shield, so this puts the extension's
                // own strings on screen.
                BlockScreenPreview(
                    subject: subject,
                    tone: ZTheme.tone(forHex: profiles.activeProfile?.accentHex))
            } else if let subject = DebugSeed.shieldPreviewSubject {
                // Screen 03 normally needs a Screen Time shield to have fired,
                // which Simulator will never allow. Standing it up as the root
                // under a launch argument is the only way to look at it while
                // building. This is the real view, not a mock of one.
                AppPausedView(subject: subject,
                              tone: ZTheme.tone(forHex: profiles.activeProfile?.accentHex),
                              remaining: "16:12",
                              onDismiss: {})
            } else {
                root
            }
            #else
            root
            #endif
        }
        .onChange(of: scenePhase) { _, phase in
            #if DEBUG
            // The shield preview is standing in for another process. Letting the
            // app's own foreground work run behind it would auto-start scheduled
            // sessions nobody asked for.
            if DebugSeed.shieldPreviewSubject != nil || DebugSeed.blockScreenPreviewSubject != nil { return }
            #endif
            switch phase {
            case .active:
                authorization.refresh()
                session.restoreIfNeeded()
                // After restore, so a session that just finished has its row.
                session.applyPendingReflection()
                session.applyPendingControlRequest()
                session.refresh()
                // Recompute the shields from what is true right now.
                //
                // The shared ManagedSettingsStore outlives every process that
                // writes to it, so it can drift: a session under fifteen minutes
                // is never handed to DeviceActivity (Apple's floor), which means
                // no extension wakes to tear it down if iOS kills the app
                // mid-session. Reconciling on foreground is what settles that.
                //
                // Safe in every state: it derives the answer from the activities
                // registered right now, so it re-asserts a live session or an
                // open schedule window and clears when neither applies.
                session.reapplyEnforcement()
                applyFocusFilterProfile()
                startPendingFocusIfNeeded()
                ScheduleAutoStart.run(schedules: schedules, session: session, profiles: profiles)
                ScheduleCountdown.run(schedules: schedules, session: session, profiles: profiles)
                rescheduleDailyReminder()
                analytics.armWeeklyRecap()
            case .background:
                BackgroundRefresh.schedule()
            default:
                break
            }
        }
    }

    private var root: some View {
        AppEntryView()
            // Text follows the user's size up to the first accessibility step,
            // roughly 1.6× the default. The Focus screen is a fixed composition
            // and the session orb has one size; past this they would overflow.
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
            .environment(authorization)
            .environment(profiles)
            .environment(schedules)
            .environment(session)
            .environment(suggestions)
            .environment(analytics)
            .environment(achievements)
            .environment(challenges)
            .environment(accountability)
            // The widget's "Start Work" tap. A widget cannot run an intent that
            // opens the app, so it sends a URL instead; this turns it into the
            // same request the intents make and starts straight away — the
            // `.active` handler may already have run by the time the URL lands.
            .onOpenURL { url in
                guard let pending = FocusLaunchRequest.pending(from: url) else { return }
                FocusLaunchRequest.request(profileID: pending.profileID)
                startPendingFocusIfNeeded()
            }
    }

    /// Start a session requested from outside the app (App Intent / Control
    /// Center / Siri / widget), using the profile it named or else the active one.
    private func startPendingFocusIfNeeded() {
        guard let pending = FocusLaunchRequest.consume(),
              session.phase == .idle else { return }
        if let id = pending.profileID, profiles.profiles.contains(where: { $0.id == id }) {
            profiles.activeProfileID = id
        }
        guard let profile = profiles.activeProfile else { return }
        session.startFocus(
            profileName: profile.name ?? "Focus",
            accentHex: profile.accentHex ?? "1A3FA8",
            focusMinutes: Int(profile.focusMinutes),
            breakMinutes: Int(profile.breakMinutes),
            isStrict: profile.isStrict,
            blockAll: profile.blockAllApps,
            allowedWebDomains: WebDomainList.parse(profile.allowedWebDomains ?? ""),
            block: profiles.block(for: profile),
            allow: profiles.allow(for: profile)
        )
    }

    /// Re-arm the smart daily reminder for today's state (focused → break nudge,
    /// not yet → start-focus nudge). No-op when the reminder is disabled.
    private func rescheduleDailyReminder() {
        let defaults = AppGroup.defaults
        guard defaults.bool(forKey: "breakReminderEnabled") else {
            NotificationService.shared.cancelDailyBreakReminder()
            return
        }
        let hour = defaults.object(forKey: "breakReminderHour") as? Int ?? 15
        let minute = defaults.object(forKey: "breakReminderMinute") as? Int ?? 0
        NotificationService.shared.scheduleDailyReminder(
            hour: hour, minute: minute,
            focusedToday: session.todayFocusMinutes() > 0)
    }

    /// Switch to the profile chosen by an active iOS Focus filter, if any.
    private func applyFocusFilterProfile() {
        guard let name = AppGroup.defaults.string(forKey: "focusFilterProfile"),
              let profile = profiles.profiles.first(where: { $0.name == name }) else { return }
        profiles.setActive(profile)
    }
}
