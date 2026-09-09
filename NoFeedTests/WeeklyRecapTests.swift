//
//  WeeklyRecapTests.swift
//  NoFeedTests
//
//  `WeeklyRecap` is a pure value type on purpose, and this is the payoff: every
//  sentence the recap can say is checked here without a store, a simulator, or a
//  week of real history behind it.
//
//  What is worth pinning is not the arithmetic — it is the claims. The recap
//  tells the reader they "stopped every time", compares their week to the last
//  one, and names a weekday to try next. Each of those is a statement that can be
//  *false*, and a false one costs more than a missing one.
//

import Testing
import Foundation
@testable import NoFeed

struct WeeklyRecapTests {

    // MARK: - Fixtures

    private func days(_ minutes: [Int]) -> [WeeklyRecap.Day] {
        let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return zip(labels, minutes).map { WeeklyRecap.Day(label: $0, minutes: $1) }
    }

    private func recap(focus: Int = 260,
                       previous: Int = 220,
                       sessions: Int = 12,
                       attempts: Int = 23,
                       held: Bool = true,
                       dayMinutes: [Int] = [50, 100, 25, 20, 45, 15, 5],
                       hadPrevious: Bool = true) -> WeeklyRecap {
        WeeklyRecap(weekStart: Date(),
                    focusMinutes: focus,
                    previousMinutes: previous,
                    sessionCount: sessions,
                    attempts: attempts,
                    heldEveryTime: held,
                    days: days(dayMinutes),
                    hadPreviousWeek: hadPrevious)
    }

    // MARK: - Duration

    @Test func minutesUnderAnHourStayMinutes() {
        #expect(WeeklyRecap.duration(45) == "45m")
        #expect(WeeklyRecap.duration(0) == "0m")
    }

    @Test func wholeHoursDropTheMinutes() {
        #expect(WeeklyRecap.duration(60) == "1h")
        #expect(WeeklyRecap.duration(180) == "3h")
    }

    @Test func mixedDurationsReadAsBoth() {
        #expect(WeeklyRecap.duration(260) == "4h 20m")
        #expect(WeeklyRecap.duration(61) == "1h 1m")
    }

    // MARK: - The resisted line
    //
    // The whole feature exists to deliver this sentence, and it is the one most
    // able to lie.

    @Test func aCleanWeekClaimsEveryTime() {
        #expect(recap(attempts: 23, held: true).resistedLine
                == "You reached for a blocked app 23 times, and stopped every time.")
    }

    /// A session walked out of downgrades the claim. Saying "every time" when a
    /// session was abandoned would be flattery the reader can disprove.
    @Test func anAbandonedSessionSoftensTheClaim() {
        #expect(recap(attempts: 23, held: false).resistedLine
                == "You reached for a blocked app 23 times, and stopped almost every time.")
    }

    @Test func oneAttemptIsSingular() {
        let line = recap(attempts: 1, held: true).resistedLine
        #expect(line == "You reached for a blocked app once, and stopped every time.")
        #expect(!line.contains("1 times"))
    }

    /// Zero is not "you resisted 0 times" — it is a different fact about the week.
    @Test func noAttemptsSaysSomethingElseEntirely() {
        let line = recap(attempts: 0).resistedLine
        #expect(line == "Nothing pulled at you this week.")
        #expect(!line.contains("stopped"))
    }

    // MARK: - Comparison

    @Test func aFirstWeekComparesToNothing() {
        #expect(recap(hadPrevious: false).comparisonLine == nil)
    }

    @Test func moreThanLastWeekSaysMore() {
        #expect(recap(focus: 260, previous: 220).comparisonLine == "40m more than the week before.")
    }

    @Test func lessThanLastWeekSaysLessWithoutAMinusSign() {
        let line = recap(focus: 180, previous: 260).comparisonLine
        #expect(line == "1h 20m less than the week before.")
        #expect(!(line ?? "").contains("-"))
    }

    /// A handful of minutes across several hours is not progress, and reporting
    /// it as progress is the padding the rest of the app avoids.
    @Test func aTinySwingReadsAsLevelRatherThanProgress() {
        #expect(recap(focus: 263, previous: 260).comparisonLine == "About the same as the week before.")
        #expect(recap(focus: 257, previous: 260).comparisonLine == "About the same as the week before.")
    }

    // MARK: - Motivation
    //
    // Never scolds. A lighter week is reported as a lighter week.

    @Test func aLighterWeekIsNotTreatedAsAFailure() {
        let note = recap(focus: 100, previous: 300).motivation
        #expect(note == "A lighter week than the last. It still counts.")
    }

    @Test func aFirstWeekIsNamedAsOne() {
        #expect(recap(hadPrevious: false).motivation == "Your first week of this. The rest builds on it.")
    }

    @Test func anEmptyWeekLooksForwardInsteadOfBack() {
        let note = recap(focus: 0, sessions: 0, attempts: 0,
                         dayMinutes: [0, 0, 0, 0, 0, 0, 0]).motivation
        #expect(note == "A week away from it. Next week is open.")
    }

    @Test func noSentenceShouts() {
        for note in [recap().motivation,
                     recap(focus: 100, previous: 300).motivation,
                     recap(hadPrevious: false).motivation,
                     recap(focus: 0, sessions: 0).motivation] {
            #expect(!note.contains("!"))
        }
    }

    // MARK: - Suggestion

    /// The point of the suggestion is that only this app could make it — a named
    /// weekday, not generic advice.
    @Test func anEmptyDayIsNamedAsTheCheapestWin() {
        let text = recap(dayMinutes: [50, 100, 25, 0, 45, 15, 5]).suggestion
        #expect(text == "Thu had none. One short session there would even out the week.")
    }

    @Test func aFullWeekPointsAtWhatAlreadyWorked() {
        let text = recap(dayMinutes: [50, 100, 25, 20, 45, 15, 5]).suggestion
        #expect(text == "Tue was your strongest day, at 1h 40m. Worth repeating.")
    }

    @Test func anEmptyWeekIsToldWhereToStart() {
        let text = recap(focus: 0, sessions: 0, attempts: 0,
                         dayMinutes: [0, 0, 0, 0, 0, 0, 0]).suggestion
        #expect(text == "Fifteen minutes is enough to start with. Pick one day next week.")
    }

    // MARK: - Shape

    @Test func aWeekWithNothingInItIsEmpty() {
        #expect(recap(focus: 0, sessions: 0, attempts: 0,
                      dayMinutes: [0, 0, 0, 0, 0, 0, 0]).isEmpty)
    }

    /// Attempts alone do not make a week non-empty: shields can fire from a
    /// schedule window without any session being run, and the recap's headline
    /// would still be "0m".
    @Test func aWeekWithSessionsIsNotEmpty() {
        #expect(!recap(focus: 20, sessions: 1).isEmpty)
    }

    // MARK: - Notification body

    /// Leads with the number, because that is what makes someone open it.
    @Test func theBannerLeadsWithTheDuration() {
        let body = recap(focus: 260, sessions: 12, attempts: 23).notificationBody
        #expect(body.hasPrefix("4h 20m of quiet across 12 sessions."))
        #expect(body.contains("23 times"))
    }

    @Test func aSingleSessionIsSingularInTheBanner() {
        let body = recap(focus: 25, sessions: 1, attempts: 0).notificationBody
        #expect(body == "25m of quiet across 1 session.")
    }

    @Test func theBannerOmitsResistanceWhenThereWasNone() {
        let body = recap(focus: 60, sessions: 2, attempts: 0).notificationBody
        #expect(!body.contains("Nothing pulled"))
    }
}

// MARK: - When the recap fires

struct WeeklyRecapScheduleTests {

    private func calendar(firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = firstWeekday
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        return calendar
    }

    /// Wednesday 14 Jan 2026, 12:00 UTC.
    private var wednesday: Date {
        DateComponents(calendar: calendar(firstWeekday: 2), timeZone: TimeZone(identifier: "UTC"),
                       year: 2026, month: 1, day: 14, hour: 12).date!
    }

    /// Most of the world: the week starts Monday, so it ends Sunday.
    @Test func aMondayFirstWeekEndsOnSunday() {
        let cal = calendar(firstWeekday: 2)
        let next = NotificationService.nextWeekEnd(hour: 18, minute: 0, from: wednesday, calendar: cal)
        #expect(cal.component(.weekday, from: next) == 1)   // 1 = Sunday
        #expect(cal.component(.hour, from: next) == 18)
    }

    /// The US: the week starts Sunday, so it ends Saturday. A recap hardcoded to
    /// Sunday evening would summarise a week six hours old for these readers —
    /// this is the case that bug would have hidden in.
    @Test func aSundayFirstWeekEndsOnSaturday() {
        let cal = calendar(firstWeekday: 1)
        let next = NotificationService.nextWeekEnd(hour: 18, minute: 0, from: wednesday, calendar: cal)
        #expect(cal.component(.weekday, from: next) == 7)   // 7 = Saturday
    }

    @Test func itIsAlwaysInTheFuture() {
        for firstWeekday in 1...7 {
            let cal = calendar(firstWeekday: firstWeekday)
            let next = NotificationService.nextWeekEnd(hour: 18, minute: 0, from: wednesday, calendar: cal)
            #expect(next > wednesday)
            #expect(next.timeIntervalSince(wednesday) <= 8 * 86_400)
        }
    }

    /// Asking on the fire day itself, an hour late, must roll to next week rather
    /// than returning a moment that has already gone by — a trigger in the past
    /// never delivers.
    @Test func askingAfterTheHourRollsToNextWeek() {
        let cal = calendar(firstWeekday: 2)
        let sundayEvening = DateComponents(calendar: cal, timeZone: TimeZone(identifier: "UTC"),
                                           year: 2026, month: 1, day: 18, hour: 19).date!
        let next = NotificationService.nextWeekEnd(hour: 18, minute: 0, from: sundayEvening, calendar: cal)
        #expect(next > sundayEvening)
        #expect(cal.component(.weekday, from: next) == 1)
    }
}
