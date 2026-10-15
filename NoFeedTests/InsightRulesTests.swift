//
//  InsightRulesTests.swift
//  NoFeedTests
//
//  The thresholds are the feature. A rule that speaks on thin evidence is
//  worse than none, so most of these check that it stays quiet.
//

import Testing
@testable import NoFeed

struct InsightRulesTests {

    private func sample(_ reflection: SessionReflection = .focused, minutes: Int = 25,
                        hour: Int = 9, profile: String = "Work") -> ReflectedSample {
        ReflectedSample(plannedMinutes: minutes, startHour: hour,
                        profileName: profile, reflection: reflection)
    }

    @Test func silentUnderTenAnsweredSessions() {
        let nine = Array(repeating: sample(), count: 9)
        #expect(InsightRules.compute(nine).isEmpty)

        // Unanswered sessions do not count toward the ten.
        let padded = nine + Array(repeating: sample(.none), count: 5)
        #expect(InsightRules.compute(padded).isEmpty)
    }

    @Test func namesTheLengthWithTheBestRecord() {
        var samples: [ReflectedSample] = []
        samples += Array(repeating: sample(.focused, minutes: 25), count: 5)
        samples += Array(repeating: sample(.distracted, minutes: 25), count: 1)
        samples += Array(repeating: sample(.focused, minutes: 50), count: 1)
        samples += Array(repeating: sample(.distracted, minutes: 50), count: 3)
        let rules = InsightRules.compute(samples)
        #expect(rules.bestLength == "Your 16–30 minute sessions go best.")
    }

    @Test func namesTheTimeOfDayAndProfile() {
        var samples: [ReflectedSample] = []
        samples += Array(repeating: sample(.focused, hour: 8, profile: "Study"), count: 5)
        samples += Array(repeating: sample(.interrupted, hour: 20, profile: "Work"), count: 5)
        let rules = InsightRules.compute(samples)
        #expect(rules.bestTimeOfDay == "Mornings are your focused hours.")
        #expect(rules.bestProfile == "Study is where you stay focused.")
    }

    @Test func aRuleNeedsTwoGroupsToCompare() {
        // Ten sessions, all one length, one hour, one profile: nothing to say.
        let uniform = Array(repeating: sample(), count: 10)
        #expect(InsightRules.compute(uniform).isEmpty)
    }

    @Test func aGroupNeedsThreeSessionsToWin() {
        var samples = Array(repeating: sample(.distracted, minutes: 25), count: 10)
        // Two perfect hour-long sessions are not enough evidence.
        samples += Array(repeating: sample(.focused, minutes: 90), count: 2)
        #expect(InsightRules.compute(samples).bestLength == nil)
    }

    @Test func nothingWinsWhenNothingWasFocused() {
        var samples = Array(repeating: sample(.distracted, minutes: 25), count: 6)
        samples += Array(repeating: sample(.interrupted, minutes: 50), count: 6)
        #expect(InsightRules.compute(samples).isEmpty)
    }

    @Test func tiesGoToTheLargerGroup() {
        var samples = Array(repeating: sample(.focused, hour: 9), count: 6)
        samples += Array(repeating: sample(.focused, hour: 20), count: 4)
        #expect(InsightRules.compute(samples).bestTimeOfDay == "Mornings are your focused hours.")
    }

    @Test func bucketsAndDayParts() {
        #expect(InsightRules.lengthBucket(15) == "short (15 minutes or less)")
        #expect(InsightRules.lengthBucket(45) == "31–45 minute")
        #expect(InsightRules.lengthBucket(61) == "hour-plus")
        #expect(InsightRules.timeOfDay(4) == "Nights")
        #expect(InsightRules.timeOfDay(16) == "Afternoons")
        #expect(InsightRules.timeOfDay(21) == "Evenings")
    }
}
