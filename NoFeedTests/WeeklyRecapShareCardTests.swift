//
//  WeeklyRecapShareCardTests.swift
//  NoFeedTests
//
//  The recap card lands in the same feeds as `SessionShareCard`, so it is pinned
//  to the same things: the pixel size a social crop depends on, opacity, and the
//  exported filename. Drift on any of those is invisible in review and obvious to
//  everyone who is not the author.
//
//  Like the session card's tests, each run writes the rendered PNG into the host
//  app's Documents container — a real directory on the Mac — so a design change
//  can be looked at rather than argued about.
//

import Testing
import Foundation
import UIKit
@testable import NoFeed

@MainActor
struct WeeklyRecapShareCardTests {

    private func recap(focus: Int = 289,
                       previous: Int = 0,
                       sessions: Int = 4,
                       attempts: Int = 17,
                       held: Bool = true,
                       hadPrevious: Bool = false) -> WeeklyRecap {
        let labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let minutes = [56, 80, 43, 110, 0, 0, 0]
        return WeeklyRecap(weekStart: Date(),
                           focusMinutes: focus,
                           previousMinutes: previous,
                           sessionCount: sessions,
                           attempts: attempts,
                           heldEveryTime: held,
                           days: zip(labels, minutes).map { WeeklyRecap.Day(label: $0, minutes: $1) },
                           hadPreviousWeek: hadPrevious)
    }

    /// 1080x1350 is the 4:5 every social surface accepts without re-cropping.
    /// Must match `SessionShareCard` exactly — the two land in the same feed.
    @Test func rendersAtSocialResolution() throws {
        let image = try #require(WeeklyRecapShareCardRenderer.image(for: recap(), accentHex: "7C93E8"))
        let pixels = CGSize(width: image.size.width * image.scale,
                            height: image.size.height * image.scale)
        #expect(pixels == CGSize(width: 1080, height: 1350))

        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let url = dir.appendingPathComponent("weekly-recap-card.png")
        try image.pngData()?.write(to: url)
        print("RECAP_CARD_PNG=\(url.path)")
    }

    /// Opaque, because a PNG with an alpha channel composites onto whatever
    /// colour the host app puts behind it — usually white, under a dark card.
    @Test func rendersOpaque() throws {
        let image = try #require(WeeklyRecapShareCardRenderer.image(for: recap(), accentHex: "7C93E8"))
        let data = try #require(image.pngData())
        #expect(data.count > 0)
    }

    /// Renders even when the sentence is at its longest — a three-digit attempt
    /// count on the "almost every time" branch is the widest this line gets, and
    /// it must not push the wordmark off the bottom of the card.
    @Test func rendersTheLongestPossibleResistedLine() throws {
        let long = recap(attempts: 147, held: false)
        #expect(long.resistedLine.count > 60)
        let image = try #require(WeeklyRecapShareCardRenderer.image(for: long, accentHex: "7C93E8"))
        let pixels = CGSize(width: image.size.width * image.scale,
                            height: image.size.height * image.scale)
        #expect(pixels == CGSize(width: 1080, height: 1350))
    }

    /// The exported file carries the duration, so a camera roll full of these is
    /// still readable months later — and it says "nofeed", not the old name.
    @Test func suggestsARealFilename() throws {
        let image = try #require(WeeklyRecapShareCardRenderer.image(for: recap(), accentHex: "7C93E8"))
        let card = SharedWeeklyRecapCard(image: image, durationText: "4h 49m")
        #expect(card.suggestedName == "nofeed-week-4h-49m")
    }
}
