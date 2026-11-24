//
//  LimitStore.swift
//  NoFeed
//
//  The app's side of daily limits: the list the screens edit, and the
//  DeviceActivity monitoring that counts usage. Storage lives in the App Group
//  (`AppLimitStore`) because the monitor extension reads it; this type keeps an
//  observable copy and keeps monitoring in step with every change.
//
//  See `AppLimit.swift` for how a used-up limit becomes a shield.
//

import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

extension DeviceActivityEvent.Name {
    static let limitReached = Self("nofeed.limit.reached")
}

@Observable
@MainActor
final class LimitStore {
    private(set) var limits: [AppLimit] = AppLimitStore.load()

    private let center = DeviceActivityCenter()

    func save(_ limit: AppLimit) {
        if let index = limits.firstIndex(where: { $0.id == limit.id }) {
            limits[index] = limit
        } else {
            limits.append(limit)
        }
        AppLimitStore.save(limits)
        // An edit is a deliberate choice, so it starts today's count afresh
        // rather than leaving yesterday's verdict (or a smaller allowance's) up.
        AppLimitStore.clearReached(limit.id)
        arm(limit)
        reconcile()
    }

    func setEnabled(_ enabled: Bool, for id: UUID) {
        guard var limit = limits.first(where: { $0.id == id }) else { return }
        limit.isEnabled = enabled
        save(limit)
    }

    func delete(_ id: UUID) {
        limits.removeAll { $0.id == id }
        AppLimitStore.save(limits)
        center.stopMonitoring([DeviceActivityName(AppLimitStore.monitorName(id))])
        AppLimitStore.clearReached(id)
        reconcile()
    }

    func isReached(_ id: UUID) -> Bool { AppLimitStore.isReached(id) }

    /// On every foreground: make sure each enabled limit is still monitored.
    /// Monitoring survives relaunches, but not a Screen Time permission that
    /// was revoked and granted again.
    func armAll() {
        limits = AppLimitStore.load()
        let running = Set(center.activities.map(\.rawValue))
        for limit in limits where limit.isEnabled && !running.contains(AppLimitStore.monitorName(limit.id)) {
            arm(limit)
        }
    }

    // MARK: - Private

    private func arm(_ limit: AppLimit) {
        let name = DeviceActivityName(AppLimitStore.monitorName(limit.id))
        center.stopMonitoring([name])
        guard limit.isEnabled, limit.itemCount > 0 else { return }

        let selection = limit.selection
        var warning: DateComponents?
        if limit.minutes > AppLimitStore.warningMinutes * 2 {
            warning = DateComponents(minute: AppLimitStore.warningMinutes)
        }
        let event = DeviceActivityEvent(applications: selection.applicationTokens,
                                        categories: selection.categoryTokens,
                                        webDomains: selection.webDomainTokens,
                                        threshold: DateComponents(minute: limit.minutes))
        let schedule = DeviceActivitySchedule(intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
                                              intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
                                              repeats: true,
                                              warningTime: warning)
        do {
            try center.startMonitoring(name, during: schedule, events: [.limitReached: event])
        } catch {
            print("[NoFeed] startMonitoring (limit) failed for \(name.rawValue): \(error)")
        }
    }

    private func reconcile() {
        ShieldReconciler.reconcile(ManagedSettingsStore(named: .noFeed))
    }
}
