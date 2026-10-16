//
//  StoreHealth.swift
//  NoFeed
//
//  The one place a storage failure is reported, so it reaches the user instead
//  of a console nobody reads.
//
//  Before this, a store that failed to open and every failed save only printed
//  to the console. The app kept running, looked normal, and silently dropped
//  every session, profile change and schedule from then on. Now the failure is
//  logged and the root view shows a banner saying what is happening.
//

import Foundation
import Observation
import os

@Observable
final class StoreHealth {
    init() {}
    static let shared = StoreHealth()

    enum Problem: Equatable {
        /// The store could not be opened. Nothing will be kept this launch.
        case unavailable(String)
        /// A save failed. Recent changes may not have been kept.
        case saveFailed(String)
    }

    private(set) var problem: Problem?

    private static let log = Logger(subsystem: "me.adithyan.shalinth.Zenly", category: "persistence")

    func storeUnavailable(_ error: Error) {
        Self.log.error("Store failed to load: \(String(describing: error), privacy: .public)")
        problem = .unavailable(error.localizedDescription)
    }

    func saveFailed(_ error: Error, in place: String) {
        Self.log.error("\(place, privacy: .public) save failed: \(String(describing: error), privacy: .public)")
        // An unavailable store is the root cause; don't replace it with its symptom.
        if case .unavailable = problem { return }
        problem = .saveFailed(error.localizedDescription)
    }

    /// The banner's dismiss. A later failure raises it again.
    func acknowledge() {
        if case .saveFailed = problem { problem = nil }
    }

    #if DEBUG
    func resetForTests() { problem = nil }
    #endif
}
