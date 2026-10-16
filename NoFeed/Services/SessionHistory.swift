//
//  SessionHistory.swift
//  NoFeed
//
//  Records completed/abandoned focus sessions to Core Data and derives streak +
//  today's focus minutes for the Home screen.
//

import CoreData
import Foundation

@MainActor
final class SessionHistory {
    private let context: NSManagedObjectContext

    init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
    }

    @discardableResult
    func record(profileName: String,
                plannedMinutes: Int,
                completedMinutes: Int,
                kind: String,
                wasCompleted: Bool,
                endedEarly: Bool,
                startedAt: Date,
                endedAt: Date) -> FocusSession {
        let session = FocusSession(context: context)
        session.id = UUID()
        session.profileName = profileName
        session.plannedMinutes = Int16(plannedMinutes)
        session.completedMinutes = Int16(completedMinutes)
        session.kind = kind
        session.wasCompleted = wasCompleted
        session.endedEarly = endedEarly
        session.startedAt = startedAt
        session.endedAt = endedAt
        save()
        return session
    }

    func save() {
        do { try context.save() }
        catch { StoreHealth.shared.saveFailed(error, in: "SessionHistory") }
    }

    /// The three numbers the Home Screen widget shows, written to the App
    /// Group. One builder, called from every session change and from Insights,
    /// so the widget and the app can never disagree about the streak.
    func writeStatsSnapshot() {
        StatsStore.save(StatsSnapshot(streak: currentStreak(),
                                      todayMinutes: todayFocusMinutes(),
                                      todayAttempts: DistractionLog.today(),
                                      updatedAt: Date()))
    }

    /// Attaches a parked notification answer to the session it names, if that
    /// session has been recorded. An answer whose session cannot be found after
    /// a day is dropped: it would otherwise sit there until a session happened
    /// to start at the same second, which is never.
    func applyPendingReflection() {
        guard let pending = ReflectionInbox.peek() else { return }
        let tolerance = ReflectionInbox.matchTolerance
        let request = FocusSession.fetchRequest()
        request.predicate = NSPredicate(format: "startedAt >= %@ AND startedAt <= %@",
                                        pending.startedAt.addingTimeInterval(-tolerance) as NSDate,
                                        pending.startedAt.addingTimeInterval(tolerance) as NSDate)
        request.fetchLimit = 1
        if let session = try? context.fetch(request).first {
            if session.reflection == .none {
                session.reflection = pending.reflection
                save()
            }
            ReflectionInbox.clear()
        } else if Date().timeIntervalSince(pending.startedAt) > 86_400 {
            ReflectionInbox.clear()
        }
    }

    /// Completed focus sessions nobody has said anything about yet, newest
    /// first. Checked in the store against both columns so a legacy-rated
    /// session does not count as unanswered. `since` keeps the question to
    /// recent sessions: nobody remembers how a session three weeks ago felt.
    func unreflectedSessions(limit: Int, since: Date) -> [FocusSession] {
        let request = FocusSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "kind == %@ AND wasCompleted == YES AND reflectionRaw == 0 AND rating == 0 AND startedAt >= %@",
            "focus", since as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSession.startedAt, ascending: false)]
        request.fetchLimit = limit
        return (try? context.fetch(request)) ?? []
    }

    /// Recent focus sessions (completed + ended-early), newest first.
    func recentFocusSessions(limit: Int = 100) -> [FocusSession] {
        let request = FocusSession.fetchRequest()
        request.predicate = NSPredicate(format: "kind == %@", "focus")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSession.startedAt, ascending: false)]
        request.fetchLimit = limit
        return (try? context.fetch(request)) ?? []
    }

    /// How many focus sessions a profile has run — the number the delete sheet
    /// quotes back ("its 12 sessions stay in your history").
    ///
    /// Counted in the store rather than by fetching and filtering: this is asked
    /// on a confirmation sheet, where the alternative is loading every session a
    /// long-standing user has ever run to answer with one integer.
    func focusSessionCount(profileName: String) -> Int {
        let request = FocusSession.fetchRequest()
        request.predicate = NSPredicate(format: "kind == %@ AND profileName == %@",
                                        "focus", profileName)
        return (try? context.count(for: request)) ?? 0
    }

    func completedFocusSessions() -> [FocusSession] {
        let request = FocusSession.fetchRequest()
        request.predicate = NSPredicate(format: "kind == %@ AND wasCompleted == YES", "focus")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSession.startedAt, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    /// Focus sessions started in `[start, end)` — **abandoned ones included**.
    ///
    /// Everything else here reads `completedFocusSessions()`, which filters the
    /// abandoned ones out. The weekly recap is the one caller that needs them: it
    /// claims the user "stopped every time" they reached for a blocked app, and
    /// that sentence is only true if no session was walked out of. Asking the
    /// completed-only fetch would make the claim unfalsifiable and therefore wrong.
    func focusSessions(from start: Date, to end: Date) -> [FocusSession] {
        let request = FocusSession.fetchRequest()
        request.predicate = NSPredicate(
            format: "kind == %@ AND startedAt >= %@ AND startedAt < %@",
            "focus", start as NSDate, end as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FocusSession.startedAt, ascending: true)]
        return (try? context.fetch(request)) ?? []
    }

    func todayFocusMinutes() -> Int {
        let calendar = Calendar.current
        return completedFocusSessions()
            .filter { $0.startedAt.map { calendar.isDateInToday($0) } ?? false }
            .reduce(0) { $0 + Int($1.completedMinutes) }
    }

    /// Consecutive days (ending today or yesterday) with at least one completed
    /// focus session.
    func currentStreak() -> Int {
        let calendar = Calendar.current
        let days = Set(completedFocusSessions().compactMap { session in
            session.startedAt.map { calendar.startOfDay(for: $0) }
        })
        guard !days.isEmpty else { return 0 }

        var day = calendar.startOfDay(for: Date())
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day),
                  days.contains(yesterday) else { return 0 }
            day = yesterday
        }

        var streak = 0
        while days.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
