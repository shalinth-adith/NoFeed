//
//  FocusScore.swift
//  NoFeed
//
//  One number for the last seven days, 0–100, made of three parts that can
//  only add up:
//
//    Time          50   focused minutes against the user's own daily goal
//    Consistency   30   days with any focus at all
//    Follow-through 20  sessions finished out of sessions started
//
//  The score this replaces subtracted a point for every reach for a blocked
//  app. That punished exactly the moment the app celebrates elsewhere ("you
//  reached for it and stopped"), so reaches are not part of it at all.
//
//  A rolling seven days rather than the calendar week, so the number does not
//  fall to zero every Monday morning.
//

import Foundation

struct FocusScore: Equatable {
    static let timeWeight = 50
    static let consistencyWeight = 30
    static let followThroughWeight = 20

    let time: Int
    let consistency: Int
    let followThrough: Int
    /// No sessions started in the window. The screen says so rather than
    /// showing a zero that reads like a judgement.
    let isEmpty: Bool

    var total: Int { time + consistency + followThrough }

    /// - Parameters:
    ///   - minutesPerDay: focused minutes on each of the last seven days.
    ///   - dailyGoalMinutes: the user's daily focus goal from Settings.
    ///   - started: focus sessions started in the window, finished or not.
    ///   - finished: of those, the ones that ran to the end.
    static func compute(minutesPerDay: [Int], dailyGoalMinutes: Int,
                        started: Int, finished: Int) -> FocusScore {
        guard started > 0 else {
            return FocusScore(time: 0, consistency: 0, followThrough: 0, isEmpty: true)
        }
        let days = max(minutesPerDay.count, 1)
        let goal = max(dailyGoalMinutes, 1) * days
        let minutes = minutesPerDay.reduce(0, +)
        let timeShare = min(1, Double(minutes) / Double(goal))
        let activeShare = Double(minutesPerDay.filter { $0 > 0 }.count) / Double(days)
        let finishShare = min(1, Double(finished) / Double(started))

        return FocusScore(time: Int((timeShare * Double(timeWeight)).rounded()),
                          consistency: Int((activeShare * Double(consistencyWeight)).rounded()),
                          followThrough: Int((finishShare * Double(followThroughWeight)).rounded()),
                          isEmpty: false)
    }

    /// The part with the most room left, so the screen can say one useful thing
    /// about raising the score instead of three.
    var nextStep: String? {
        guard !isEmpty else { return nil }
        let gaps = [
            (Self.timeWeight - time, String(localized: "More time toward your daily goal lifts it most.")),
            (Self.consistencyWeight - consistency, String(localized: "Focusing on more days lifts it most.")),
            (Self.followThroughWeight - followThrough, String(localized: "Finishing the sessions you start lifts it most.")),
        ]
        guard let best = gaps.max(by: { $0.0 < $1.0 }), best.0 > 0 else { return nil }
        return best.1
    }
}
