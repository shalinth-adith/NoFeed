//
//  InsightRules.swift
//  NoFeed
//
//  "What works for you": three sentences computed from how sessions felt.
//  Which length, which time of day, which profile has the best record of
//  ending with "Focused".
//
//  A pure value type on purpose, like `WeeklyRecap`: it takes a list of plain
//  samples and returns sentences, so every rule has a test that needs no
//  store. `AnalyticsService` turns Core Data rows into samples.
//
//  Thresholds are what keep this honest. Nothing is said until ten sessions
//  have an answer; a group needs three sessions before it can win; and a rule
//  with only one group to compare has nothing to compare, so it stays quiet.
//  Three focused sessions out of three is not a pattern, it is a Tuesday.
//

import Foundation

struct ReflectedSample: Equatable {
    let plannedMinutes: Int
    /// Hour of day the session started, 0–23, in the user's calendar.
    let startHour: Int
    let profileName: String
    let reflection: SessionReflection
}

struct InsightRules: Equatable {
    static let minimumSamples = 10
    static let minimumGroupSize = 3

    let bestLength: String?
    let bestTimeOfDay: String?
    let bestProfile: String?

    var isEmpty: Bool { bestLength == nil && bestTimeOfDay == nil && bestProfile == nil }
    var lines: [String] { [bestLength, bestTimeOfDay, bestProfile].compactMap { $0 } }

    static let empty = InsightRules(bestLength: nil, bestTimeOfDay: nil, bestProfile: nil)

    static func compute(_ samples: [ReflectedSample]) -> InsightRules {
        let answered = samples.filter { $0.reflection != .none }
        guard answered.count >= minimumSamples else { return .empty }

        let length = winner(of: answered, by: { lengthBucket($0.plannedMinutes) })
            .map { "Your \($0) sessions go best." }
        let time = winner(of: answered, by: { timeOfDay($0.startHour) })
            .map { "\($0) are your focused hours." }
        let profile = winner(of: answered, by: { $0.profileName })
            .map { "\($0) is where you stay focused." }

        return InsightRules(bestLength: length, bestTimeOfDay: time, bestProfile: profile)
    }

    // MARK: - Grouping

    /// The group with the highest share of focused sessions, or nil when no
    /// group is big enough or there is only one group to compare against.
    /// Ties go to the larger group: more evidence beats an equal ratio.
    static func winner(of samples: [ReflectedSample],
                       by key: (ReflectedSample) -> String) -> String? {
        let groups = Dictionary(grouping: samples, by: key)
            .filter { $0.value.count >= minimumGroupSize }
        guard groups.count >= 2 else { return nil }

        var bestName: String?
        var bestShare = 0.0
        var bestSize = 0
        for (name, members) in groups {
            let focused = members.filter { $0.reflection == .focused }.count
            let share = Double(focused) / Double(members.count)
            let better = share > bestShare || (share == bestShare && members.count > bestSize)
            if better {
                bestName = name
                bestShare = share
                bestSize = members.count
            }
        }
        guard bestShare > 0 else { return nil }
        return bestName
    }

    static func lengthBucket(_ minutes: Int) -> String {
        switch minutes {
        case ..<16: return "short (15 minutes or less)"
        case 16...30: return "16–30 minute"
        case 31...45: return "31–45 minute"
        case 46...60: return "46–60 minute"
        default: return "hour-plus"
        }
    }

    static func timeOfDay(_ hour: Int) -> String {
        switch hour {
        case 5...11: return "Mornings"
        case 12...16: return "Afternoons"
        case 17...21: return "Evenings"
        default: return "Nights"
        }
    }
}
