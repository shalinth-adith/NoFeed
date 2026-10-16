//
//  ProfileRenameTests.swift
//  NoFeedTests
//
//  Renaming a profile must carry its history and its schedules with it.
//  Sessions and schedules refer to a profile by name, so a rename that only
//  touched the profile split its history and left its schedules unable to
//  find the profile they start.
//

import Testing
import CoreData
@testable import NoFeed

@MainActor
@Suite(.serialized)
struct ProfileRenameTests {

    @Test func renameCarriesSessionsAndSchedules() throws {
        let context = PersistenceController(inMemory: true).container.viewContext
        let store = ProfileStore(context: context)
        let work = try #require(store.profiles.first { $0.name == "Work" })

        let history = SessionHistory(context: context)
        history.record(profileName: "Work", plannedMinutes: 25, completedMinutes: 25, kind: "focus",
                       wasCompleted: true, endedEarly: false, startedAt: Date(), endedAt: Date())
        history.record(profileName: "Study", plannedMinutes: 50, completedMinutes: 50, kind: "focus",
                       wasCompleted: true, endedEarly: false, startedAt: Date(), endedAt: Date())

        let schedule = FocusSchedule(context: context)
        schedule.id = UUID()
        schedule.profileName = "Work"
        schedule.title = "Work"
        let titled = FocusSchedule(context: context)
        titled.id = UUID()
        titled.profileName = "Work"
        titled.title = "Deep focus"
        try context.save()

        var draft = ProfileDraft()
        draft.name = "Deep work"
        draft.focusMinutes = Int(work.focusMinutes)
        store.update(work, with: draft)

        let sessions = try context.fetch(FocusSession.fetchRequest())
        #expect(sessions.filter { $0.profileName == "Deep work" }.count == 1)
        #expect(sessions.filter { $0.profileName == "Work" }.isEmpty)
        #expect(sessions.filter { $0.profileName == "Study" }.count == 1, "other profiles are untouched")

        #expect(schedule.profileName == "Deep work")
        #expect(schedule.title == "Deep work", "a title that was just the old name follows it")
        #expect(titled.profileName == "Deep work")
        #expect(titled.title == "Deep focus", "a title of its own is kept")
    }

    @Test func saveFailureIsReportedAndDismissible() {
        let health = StoreHealth()
        struct Failure: Error {}
        health.saveFailed(Failure(), in: "Test")
        guard case .saveFailed = health.problem else {
            Issue.record("a failed save was not reported"); return
        }
        health.acknowledge()
        #expect(health.problem == nil)
    }

    @Test func unavailableStoreOutranksLaterSaveFailures() {
        let health = StoreHealth()
        struct Failure: Error {}
        health.storeUnavailable(Failure())
        health.saveFailed(Failure(), in: "Test")
        guard case .unavailable = health.problem else {
            Issue.record("the root cause was replaced by its symptom"); return
        }
        health.acknowledge()
        guard case .unavailable = health.problem else {
            Issue.record("an unavailable store must not be dismissible"); return
        }
    }
}
