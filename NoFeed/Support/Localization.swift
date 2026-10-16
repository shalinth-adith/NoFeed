//
//  Localization.swift
//  NoFeed
//
//  The app's copy is translatable through String Catalogs (`Localizable.xcstrings`
//  in each target). Design-system components take their labels as
//  `LocalizedStringResource`, so a literal written at a call site is extracted
//  and translated automatically.
//
//  User data — a profile's name, a domain, a time the system formatted — must
//  never be looked up as a key. Pass it through `.verbatim(_:)`, which shows the
//  text exactly as given.
//

import Foundation

extension LocalizedStringResource {
    /// Shows `text` as given, never translated. For user data and values that
    /// are already formatted or already localized.
    static func verbatim(_ text: String) -> LocalizedStringResource {
        // "%@" is the only catalog entry this creates; it maps to itself.
        "\(text)"
    }
}
