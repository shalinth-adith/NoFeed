//
//  FeedbackMailTests.swift
//  NoFeedTests
//
//  The feedback link has to survive a mail client's parser: every reserved
//  character in the body must be percent-encoded, and the facts the body exists
//  to carry must actually be in it.
//

import Testing
import Foundation
@testable import NoFeed

struct FeedbackMailTests {

    private let url = FeedbackMail.url(version: "2.3", build: "1",
                                       system: "26.0", device: "iPhone16,2")

    @Test func addressesTheSupportMailbox() throws {
        let url = try #require(url)
        #expect(url.scheme == "mailto")
        #expect(url.path == FeedbackMail.address)
    }

    @Test func carriesSubjectAndDeviceFacts() throws {
        let url = try #require(url)
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let subject = items.first { $0.name == "subject" }?.value
        let body = items.first { $0.name == "body" }?.value
        #expect(subject == "NoFeed feedback")
        #expect(body?.contains("NoFeed 2.3 (1)") == true)
        #expect(body?.contains("iOS 26.0") == true)
        #expect(body?.contains("iPhone16,2") == true)
    }

    @Test func encodesEveryReservedCharacter() throws {
        let raw = try #require(url).absoluteString
        #expect(!raw.contains("\n"))
        #expect(!raw.contains(" "))
        #expect(!raw.contains(","))
        #expect(!raw.contains("("))
        // The em dash and the newlines must round-trip through percent-encoding.
        #expect(raw.contains("%E2%80%94"))
        #expect(raw.contains("%0A"))
    }
}
