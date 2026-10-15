//
//  WeeklyRecapHighlightTests.swift
//  NoFeedTests
//
//  The share card's streak-and-best-day line. The rule under test is the
//  omission rule: a zero streak or a week with no minutes must drop its half
//  of the line, and a week with neither must produce no line at all.
//

import Testing
import Foundation
@testable import NoFeed

struct WeeklyRecapHighlightTests {

    private func recap(minutes: [Int], streak: Int) -> WeeklyRecap {
        let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return WeeklyRecap(weekStart: Date(),
                           focusMinutes: minutes.reduce(0, +),
                           previousMinutes: 0,
                           sessionCount: minutes.filter { $0 > 0 }.count,
                           attempts: 0,
                           heldEveryTime: true,
                           days: zip(labels, minutes).map { WeeklyRecap.Day(label: $0, minutes: $1) },
                           hadPreviousWeek: false,
                           streak: streak)
    }

    @Test func namesBothStreakAndBestDay() {
        let recap = recap(minutes: [20, 90, 30, 0, 0, 0, 0], streak: 4)
        #expect(recap.bestDay?.label == "Tue")
        #expect(recap.highlightLine == "4-day streak · strongest on Tue")
    }

    @Test func dropsAZeroStreak() {
        let recap = recap(minutes: [20, 90, 30, 0, 0, 0, 0], streak: 0)
        #expect(recap.highlightLine == "strongest on Tue")
    }

    @Test func dropsAnEmptyWeek() {
        let recap = recap(minutes: [0, 0, 0, 0, 0, 0, 0], streak: 2)
        #expect(recap.bestDay == nil)
        #expect(recap.highlightLine == "2-day streak")
    }

    @Test func saysNothingWhenThereIsNothing() {
        let recap = recap(minutes: [0, 0, 0, 0, 0, 0, 0], streak: 0)
        #expect(recap.highlightLine == nil)
    }

    @Test func existingCallersStillCompileWithoutAStreak() {
        let recap = WeeklyRecap(weekStart: Date(), focusMinutes: 10, previousMinutes: 0,
                                sessionCount: 1, attempts: 0, heldEveryTime: true,
                                days: [], hadPreviousWeek: false)
        #expect(recap.streak == 0)
    }
}
