//
//  AnalyticsService.swift
//  NoFeed
//
//  Derives weekly stats, a productivity score, and the widget snapshot from
//  completed sessions (Core Data) + the distraction log (App Group).
//

import Foundation
import Observation
import WidgetKit

struct DayStat: Identifiable {
    let id = UUID()
    let date: Date
    let label: String
    let focusMinutes: Int
    let attempts: Int
}

@Observable
@MainActor
final class AnalyticsService {
    private let history: SessionHistory

    init(history: SessionHistory? = nil) {
        self.history = history ?? SessionHistory()
    }

    /// Focus minutes + distraction attempts for the last 7 days (oldest first).
    func weeklyStats() -> [DayStat] {
        let calendar = Calendar.current
        let sessions = history.completedFocusSessions()
        let attempts = DistractionLog.counts()
        let today = calendar.startOfDay(for: Date())

        let weekdayLabel = DateFormatter()
        weekdayLabel.dateFormat = "EEE"

        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let minutes = sessions
                .filter { $0.startedAt.map { calendar.isDate($0, inSameDayAs: day) } ?? false }
                .reduce(0) { $0 + Int($1.completedMinutes) }
            return DayStat(
                date: day,
                label: weekdayLabel.string(from: day),
                focusMinutes: minutes,
                attempts: attempts[DistractionLog.dayKey(day)] ?? 0
            )
        }
    }

    // MARK: - The calendar week (Insights)

    /// Focus minutes + distraction attempts for **this calendar week**, first
    /// weekday first.
    ///
    /// Distinct from `weeklyStats()`, which is a rolling 7-day window. Insights
    /// draws the comp's chart — labels running M T W T F S S with *today*
    /// highlighted in the tone wherever it falls, and the days still to come
    /// sitting empty — and every number around it ("7.2 hours this week",
    /// "+1.1 h vs last week", "7.2 / 10 h") is only true of a week that starts
    /// somewhere. A rolling window would rotate the labels every day and make
    /// "this week" mean a different seven days each time you looked.
    ///
    /// The rolling window is kept for `productivityScore()`, which should not
    /// reset to zero every Monday morning.
    func calendarWeekStats() -> [DayStat] {
        let calendar = Calendar.current
        let sessions = history.completedFocusSessions()
        let attempts = DistractionLog.counts()
        let start = Self.startOfWeek(calendar: calendar)

        let weekdayLabel = DateFormatter()
        weekdayLabel.dateFormat = "EEE"

        return (0..<7).compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            let minutes = sessions
                .filter { $0.startedAt.map { calendar.isDate($0, inSameDayAs: day) } ?? false }
                .reduce(0) { $0 + Int($1.completedMinutes) }
            return DayStat(
                date: day,
                label: weekdayLabel.string(from: day),
                focusMinutes: minutes,
                attempts: attempts[DistractionLog.dayKey(day)] ?? 0
            )
        }
    }

    /// Completed focus minutes in the calendar week before this one — the
    /// "vs last week" comparison. Compares whole weeks against whole weeks.
    func previousCalendarWeekMinutes() -> Int {
        let calendar = Calendar.current
        let thisWeek = Self.startOfWeek(calendar: calendar)
        guard let lastWeek = calendar.date(byAdding: .day, value: -7, to: thisWeek) else { return 0 }
        return history.completedFocusSessions()
            .filter { session in
                guard let start = session.startedAt else { return false }
                return start >= lastWeek && start < thisWeek
            }
            .reduce(0) { $0 + Int($1.completedMinutes) }
    }

    /// Completed sessions so far this calendar week (the Sessions goal, and the
    /// summary screen's "that's your fourth this week").
    func calendarWeekSessionCount() -> Int {
        let start = Self.startOfWeek(calendar: Calendar.current)
        return history.completedFocusSessions()
            .filter { ($0.startedAt ?? .distantPast) >= start }
            .count
    }

    /// Midnight on the first day of the current week, in the user's locale —
    /// Monday in most of the world, Sunday in the US. The comp draws a
    /// Monday-first week; honouring `Calendar.current` is what makes it read
    /// correctly for everyone else.
    private static func startOfWeek(calendar: Calendar) -> Date {
        let today = calendar.startOfDay(for: Date())
        return calendar.dateInterval(of: .weekOfYear, for: today)?.start ?? today
    }

    // MARK: - Weekly recap

    /// The current calendar week, gathered into a `WeeklyRecap`.
    ///
    /// "Current" is right because the recap is delivered on the *last* day of the
    /// locale's week (see `NotificationService.scheduleWeeklyRecap`), so at the
    /// moment it fires this week is the week that is ending. Anchoring to the
    /// calendar rather than to a hardcoded Sunday is what keeps that true in the
    /// US, where the week starts on Sunday and a "Sunday recap" would otherwise
    /// summarise a week six hours old.
    func weeklyRecap() -> WeeklyRecap {
        let calendar = Calendar.current
        let start = Self.startOfWeek(calendar: calendar)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        let stats = calendarWeekStats()

        // Abandoned sessions are why this asks for the unfiltered fetch: one
        // walked-out-of session downgrades "stopped every time" to "almost".
        let held = !history.focusSessions(from: start, to: end).contains { $0.endedEarly }

        // Anything completed before this week means there is a real basis for
        // comparison, even if last week itself was empty. Without this an app
        // opened for the first time on a Friday would claim it did "45m less
        // than the week before" against a week that never happened.
        let hadPrevious = history.completedFocusSessions()
            .contains { ($0.startedAt ?? .distantFuture) < start }

        return WeeklyRecap(
            weekStart: start,
            focusMinutes: stats.reduce(0) { $0 + $1.focusMinutes },
            previousMinutes: previousCalendarWeekMinutes(),
            sessionCount: calendarWeekSessionCount(),
            attempts: stats.reduce(0) { $0 + $1.attempts },
            heldEveryTime: held,
            days: stats.map { WeeklyRecap.Day(label: $0.label, minutes: $0.focusMinutes) },
            hadPreviousWeek: hadPrevious
        )
    }

    /// Arm — or clear — the weekly recap notification for the end of this week.
    ///
    /// The single place that decision is made. Three callers need it and they
    /// must not disagree: app foreground (`NoFeedApp`), the settings toggle, and
    /// the session summary — the last because finishing a session in the
    /// foreground never produces a `scenePhase` change, so without it the first
    /// session of a week would not arm the recap until the app was backgrounded
    /// and reopened.
    ///
    /// Refuses to arm an empty week. An unprompted "0m of quiet across 0
    /// sessions" is a guilt notification, and this app does not send those.
    ///
    /// Defaults to on when the key was never written — `bool(forKey:)` reads an
    /// unset key as false, which would ship the feature silently disabled.
    func armWeeklyRecap() {
        let defaults = AppGroup.defaults
        let enabled = defaults.object(forKey: "weeklyRecapEnabled") as? Bool ?? true
        let recap = weeklyRecap()

        guard enabled, !recap.isEmpty else {
            NotificationService.shared.cancelWeeklyRecap()
            return
        }
        NotificationService.shared.scheduleWeeklyRecap(
            hour: defaults.object(forKey: "weeklyRecapHour") as? Int ?? 18,
            minute: defaults.object(forKey: "weeklyRecapMinute") as? Int ?? 0,
            body: recap.notificationBody
        )
    }

    // MARK: - Score

    /// 0–100 score: focus volume + consistency, minus distraction attempts.
    func productivityScore() -> Int {
        let stats = weeklyStats()
        let totalFocus = stats.reduce(0) { $0 + $1.focusMinutes }
        let totalAttempts = stats.reduce(0) { $0 + $1.attempts }
        let activeDays = stats.filter { $0.focusMinutes > 0 }.count

        let focusComponent = min(60.0, Double(totalFocus) / (7.0 * 60.0) * 60.0) // 60 min/day target
        let consistencyComponent = Double(activeDays) / 7.0 * 40.0
        let penalty = min(20.0, Double(totalAttempts))

        return max(0, min(100, Int(focusComponent + consistencyComponent - penalty)))
    }

    func streak() -> Int { history.currentStreak() }
    func todayMinutes() -> Int { history.todayFocusMinutes() }

    /// Completed focus minutes for the 7 days BEFORE the current window
    /// (days 8–14 ago) — the "vs last week" comparison on Insights.
    func previousWeekMinutes() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let windowEnd = calendar.date(byAdding: .day, value: -6, to: today),
              let windowStart = calendar.date(byAdding: .day, value: -13, to: today) else { return 0 }
        return history.completedFocusSessions()
            .filter { session in
                guard let start = session.startedAt else { return false }
                return start >= windowStart && start < windowEnd
            }
            .reduce(0) { $0 + Int($1.completedMinutes) }
    }

    /// Completed sessions in the current 7-day window (weekly sessions goal).
    func weekSessionCount() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let windowStart = calendar.date(byAdding: .day, value: -6, to: today) else { return 0 }
        return history.completedFocusSessions()
            .filter { ($0.startedAt ?? .distantPast) >= windowStart }
            .count
    }

    /// Most recent focus sessions (completed + ended early) for the Insights
    /// history list.
    /// Sessions run under one profile — what the delete sheet promises is kept.
    func sessionCount(profileName: String) -> Int {
        history.focusSessionCount(profileName: profileName)
    }

    func recentSessions(limit: Int = 5) -> [FocusSession] {
        history.recentFocusSessions(limit: limit)
    }

    /// Number of focus sessions completed today (a daily-goal "need").
    func todaySessions() -> Int {
        let calendar = Calendar.current
        return history.completedFocusSessions()
            .filter { $0.startedAt.map { calendar.isDateInToday($0) } ?? false }
            .count
    }

    /// Refresh the widget snapshot and reload timelines.
    func updateSnapshot() {
        let snapshot = StatsSnapshot(
            streak: streak(),
            todayMinutes: todayMinutes(),
            todayAttempts: DistractionLog.today(),
            updatedAt: Date()
        )
        StatsStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()
    }
}
