//
//  FocusScoreTests.swift
//  NoFeedTests
//

import Testing
@testable import NoFeed

struct FocusScoreTests {

    @Test func noSessionsIsEmptyNotZero() {
        let score = FocusScore.compute(minutesPerDay: Array(repeating: 0, count: 7),
                                       dailyGoalMinutes: 60, started: 0, finished: 0)
        #expect(score.isEmpty)
        #expect(score.nextStep == nil)
    }

    @Test func meetingEveryPartIsAHundred() {
        let score = FocusScore.compute(minutesPerDay: Array(repeating: 60, count: 7),
                                       dailyGoalMinutes: 60, started: 7, finished: 7)
        #expect(score.total == 100)
        #expect(score.nextStep == nil)
    }

    @Test func goingPastTheGoalDoesNotOverflow() {
        let score = FocusScore.compute(minutesPerDay: Array(repeating: 300, count: 7),
                                       dailyGoalMinutes: 60, started: 7, finished: 7)
        #expect(score.time == FocusScore.timeWeight)
        #expect(score.total == 100)
    }

    @Test func partsAreProportional() {
        // Half the goal's minutes, on 2 of 7 days, finishing 1 of 2 sessions.
        let score = FocusScore.compute(minutesPerDay: [105, 105, 0, 0, 0, 0, 0],
                                       dailyGoalMinutes: 60, started: 2, finished: 1)
        #expect(score.time == 25)
        #expect(score.consistency == 9)   // 2/7 of 30
        #expect(score.followThrough == 10)
        #expect(score.total == 44)
    }

    @Test func nextStepPointsAtTheBiggestGap() {
        let score = FocusScore.compute(minutesPerDay: [420, 0, 0, 0, 0, 0, 0],
                                       dailyGoalMinutes: 60, started: 1, finished: 1)
        // Time is full; consistency has 26 points left, the most of any part.
        #expect(score.nextStep?.contains("more days") == true)
    }
}
