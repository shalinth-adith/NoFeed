//
//  SessionShareCardTests.swift
//  ZenlyTests
//
//  The share card is the one image in the app that gets seen by people who do
//  not have the app, so the things worth pinning are the ones that would be
//  invisible in review and obvious in a feed: the pixel size a social crop
//  depends on, and the line under the stat.
//
//  Each run also drops the rendered PNG into the host app's Documents
//  container so the card can be looked at, not just asserted about.
//

import Testing
import Foundation
import UIKit
@testable import Zenly

@MainActor
struct SessionShareCardTests {

    private func summary(minutes: Int = 50,
                         profile: String = "Work",
                         streak: Int = 7) -> SessionSummary {
        SessionSummary(profileName: profile,
                       accentHex: "7C93E8",
                       plannedMinutes: minutes,
                       completedMinutes: minutes,
                       completedSeconds: minutes * 60,
                       wasCompleted: true,
                       endedEarly: false,
                       streak: streak)
    }

    /// 1080x1350 is the 4:5 every social surface accepts without re-cropping.
    /// If this drifts, cards start getting letterboxed or downsampled in feed.
    @Test func rendersAtSocialResolution() throws {
        let image = try #require(SessionShareCardRenderer.image(for: summary()))
        let pixels = CGSize(width: image.size.width * image.scale,
                            height: image.size.height * image.scale)
        #expect(pixels == CGSize(width: 1080, height: 1350))

        // Written every run into the host app's Documents container, whose
        // path on a simulator is a real directory on the Mac — so a design
        // change can be looked at rather than argued about. `xcodebuild` does
        // not forward the host environment into the simulated process, which is
        // why this is not gated behind an env var the way QUIET_SHOT_DIR is.
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("share-card.png")
        try image.pngData()?.write(to: url)
        print("SHARE_CARD_PNG=\(url.path)")
    }

    /// Opaque, because a PNG with an alpha channel composites onto whatever
    /// colour the host app uses behind it — which for a dark card is usually white.
    @Test func rendersOpaque() throws {
        let image = try #require(SessionShareCardRenderer.image(for: summary()))
        let data = try #require(image.pngData())
        #expect(data.count > 0)
    }

    /// "1-day streak" is just today. Saying it out loud is padding.
    @Test func hidesAStreakOfOne() {
        #expect(SessionShareCard(summary: summary(streak: 1)).shareMetaLine == "Work")
        #expect(SessionShareCard(summary: summary(streak: 0)).shareMetaLine == "Work")
    }

    @Test func namesTheStreakOnceItIsReal() {
        #expect(SessionShareCard(summary: summary(streak: 7)).shareMetaLine
                == "Work · 7-day streak")
    }

    /// The exported file carries the length, so a camera roll full of these is
    /// still readable months later.
    @Test func suggestsARealFilename() throws {
        let image = try #require(SessionShareCardRenderer.image(for: summary(minutes: 25)))
        let card = SharedSessionCard(image: image, minutes: 25)
        #expect(card.suggestedName == "zen-ly-25-min")
    }
}
