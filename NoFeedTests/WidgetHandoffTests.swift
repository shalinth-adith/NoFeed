//
//  WidgetHandoffTests.swift
//  NoFeedTests
//
//  The two contracts the widget depends on: the profile directory it reads,
//  and the start request it sends — by intent or by URL — that the app
//  consumes. Each test uses its own UserDefaults suite.
//

import Testing
import Foundation
@testable import NoFeed

struct WidgetHandoffTests {

    private func freshDefaults() -> UserDefaults {
        let name = "WidgetHandoffTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private let work = ProfileSummary(id: UUID(), name: "Work", accentHex: "7C93E8", focusMinutes: 25)
    private let study = ProfileSummary(id: UUID(), name: "Study", accentHex: "D6A85C", focusMinutes: 45)

    @Test func directoryRoundTripsAndFindsTheActiveProfile() {
        let defaults = freshDefaults()
        ProfileDirectory.save([work, study], defaults: defaults)
        #expect(ProfileDirectory.load(defaults: defaults) == [work, study])
        #expect(ProfileDirectory.profile(id: study.id, defaults: defaults) == study)

        // No active id recorded → the first profile, like the Focus tab.
        #expect(ProfileDirectory.active(defaults: defaults) == work)
        defaults.set(study.id.uuidString, forKey: "activeProfileID")
        #expect(ProfileDirectory.active(defaults: defaults) == study)
    }

    @Test func requestIsConsumedOnceWithItsProfile() {
        let defaults = freshDefaults()
        #expect(FocusLaunchRequest.consume(defaults: defaults) == nil)

        FocusLaunchRequest.request(profileID: study.id, defaults: defaults)
        #expect(FocusLaunchRequest.consume(defaults: defaults) == FocusLaunchRequest.Pending(profileID: study.id))
        #expect(FocusLaunchRequest.consume(defaults: defaults) == nil, "consumed once")

        FocusLaunchRequest.request(defaults: defaults)
        #expect(FocusLaunchRequest.consume(defaults: defaults) == FocusLaunchRequest.Pending(profileID: nil))
    }

    @Test func urlCarriesTheProfileBothWays() {
        let url = FocusLaunchRequest.url(profileID: work.id)
        #expect(url.absoluteString == "nofeed://start?profile=\(work.id.uuidString)")
        #expect(FocusLaunchRequest.pending(from: url) == FocusLaunchRequest.Pending(profileID: work.id))

        let bare = FocusLaunchRequest.url(profileID: nil)
        #expect(bare.absoluteString == "nofeed://start")
        #expect(FocusLaunchRequest.pending(from: bare) == FocusLaunchRequest.Pending(profileID: nil))

        #expect(FocusLaunchRequest.pending(from: URL(string: "nofeed://settings")!) == nil)
        #expect(FocusLaunchRequest.pending(from: URL(string: "https://example.test/start")!) == nil)
    }
}
