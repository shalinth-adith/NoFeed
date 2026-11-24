//
//  AppLimit.swift
//  NoFeed (shared: app, monitor, shield, shield action)
//
//  A daily allowance for a set of apps: "Instagram and TikTok, 30 minutes a
//  day". Stored in the App Group because the monitor extension, which runs in
//  its own process, is what notices the time running out.
//
//  How a limit is enforced, end to end:
//
//    1. The app monitors `monitorName(id)` daily from 00:00 to 23:59 with one
//       DeviceActivityEvent whose threshold is the allowance.
//    2. When the allowance is used up, the monitor's `eventDidReachThreshold`
//       calls `markReached`, which registers an ordinary enforcer — the limit's
//       apps, until the start of tomorrow — in `ActivityShieldStore`.
//    3. `ShieldReconciler` shields the union of every enforcer, as it already
//       does for sessions and schedules. Nothing else learns about limits.
//    4. At midnight the next interval starts and `clearReached` drops it. The
//       enforcer's absolute end date makes it expire on its own even if that
//       wake-up never comes.
//
//  The monitored activity itself is never registered as an enforcer. If it
//  were, the apps would be shielded all day from 00:00.
//

import Foundation
import FamilyControls

struct AppLimit: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = ""
    var minutes: Int = 30
    var isEnabled: Bool = true
    /// `FamilyActivitySelection`, encoded by `SelectionCodec`.
    var selectionData: Data?

    var selection: FamilyActivitySelection {
        get { SelectionCodec.decode(selectionData) }
        set { selectionData = SelectionCodec.encode(newValue) }
    }

    var itemCount: Int {
        let s = selection
        return s.applicationTokens.count + s.categoryTokens.count + s.webDomainTokens.count
    }

    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? String(localized: "Daily limit") : trimmed
    }
}

enum AppLimitStore {
    private static let key = "appLimits"
    private static let monitorPrefix = "nofeed.limit."
    private static let reachedSuffix = ".reached"

    /// Allowances offered in the editor, in minutes.
    static let step = 5
    static let range = 5...240
    /// The heads-up arrives this many minutes before the allowance runs out.
    static let warningMinutes = 5

    static func load() -> [AppLimit] {
        guard let data = AppGroup.defaults.data(forKey: key),
              let limits = try? JSONDecoder().decode([AppLimit].self, from: data) else { return [] }
        return limits
    }

    static func save(_ limits: [AppLimit]) {
        AppGroup.defaults.set(try? JSONEncoder().encode(limits), forKey: key)
    }

    static func limit(id: UUID) -> AppLimit? { load().first { $0.id == id } }

    // MARK: Names

    /// The daily DeviceActivity that counts usage. Never an enforcer.
    static func monitorName(_ id: UUID) -> String { monitorPrefix + id.uuidString }

    /// The enforcer registered once the allowance is used up.
    static func reachedName(_ id: UUID) -> String { monitorName(id) + reachedSuffix }

    static func limitID(fromMonitor name: String) -> UUID? {
        guard name.hasPrefix(monitorPrefix), !name.hasSuffix(reachedSuffix) else { return nil }
        return UUID(uuidString: String(name.dropFirst(monitorPrefix.count)))
    }

    static func isReachedEnforcer(_ name: String) -> Bool {
        name.hasPrefix(monitorPrefix) && name.hasSuffix(reachedSuffix)
    }

    // MARK: Reaching and resetting

    /// Shield this limit's apps until the start of tomorrow.
    static func markReached(_ id: UUID, now: Date = Date(), calendar: Calendar = .current) {
        guard let limit = limit(id: id), limit.isEnabled else { return }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
        ActivityShieldStore.set(block: limit.selection,
                                allow: FamilyActivitySelection(),
                                blockAll: false,
                                absoluteWindow: (now, tomorrow),
                                for: reachedName(id))
    }

    static func clearReached(_ id: UUID) {
        ActivityShieldStore.remove(for: reachedName(id))
    }

    static func isReached(_ id: UUID, now: Date = Date()) -> Bool {
        ActivityShieldStore.isActive(reachedName(id), now: now)
            && ActivityShieldStore.absoluteWindow(for: reachedName(id)) != nil
    }

    /// True when a used-up limit is one of the things shielding right now — the
    /// block screen words itself differently for it.
    static func anyReachedNow(_ now: Date = Date()) -> Bool {
        ActivityShieldStore.activeActivitiesNow(now).contains(where: isReachedEnforcer)
    }
}
