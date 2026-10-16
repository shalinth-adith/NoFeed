//
//  LocalizationTests.swift
//  NoFeedTests
//
//  Counts used to be pluralised by appending "s", which no other language
//  can translate. These check that the catalog's plural rules are what
//  actually choose the form, in English and in a translated language, and
//  that every shipped language is in the bundle.
//

import Testing
import Foundation
@testable import NoFeed

struct LocalizationTests {

    private func localized(_ resource: LocalizedStringResource, _ language: String) -> String {
        var resource = resource
        resource.locale = Locale(identifier: language)
        return String(localized: resource)
    }

    @Test func englishPicksSingularAndPlural() {
        #expect(localized("\(1) apps blocked", "en") == "1 app blocked")
        #expect(localized("\(3) apps blocked", "en") == "3 apps blocked")
        #expect(localized("\(1) sessions", "en") == "1 session")
        #expect(localized("\(1) minutes", "en") == "1 minute")
    }

    @Test func substitutionKeepsTheOtherArgument() {
        let name = "Work"
        #expect(localized("\(name) begins in \(1) minutes.", "en") == "Work begins in 1 minute.")
        #expect(localized("\(name) begins in \(5) minutes.", "en") == "Work begins in 5 minutes.")
    }

    @Test func translatedLanguageUsesItsOwnForms() {
        let one = localized("\(1) apps blocked", "de")
        let many = localized("\(4) apps blocked", "de")
        #expect(one != "1 app blocked")
        #expect(one.contains("1"))
        #expect(many.contains("4"))
        #expect(one != many.replacingOccurrences(of: "4", with: "1"))
    }

    @Test(arguments: ["es", "fr", "de", "ja", "pt-BR"])
    func everyShippedLanguageIsBundled(_ language: String) {
        #expect(Bundle.main.localizations.contains(language))
    }
}
