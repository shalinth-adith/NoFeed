//
//  TimeFormatting.swift
//  NoFeed
//
//  Clock text shared by the app and the widget.
//

import Foundation

extension Date {
    /// "9:00 AM" → "9:00", "21:00" → "21:00". The hour pattern with the AM/PM
    /// omitted pads to "09" in US English, so the short style is taken whole
    /// and only its day-period symbol is removed.
    static func removingMeridiem(from time: String, calendar: Calendar = .current) -> String {
        var result = time
        for symbol in [calendar.amSymbol, calendar.pmSymbol] where !symbol.isEmpty {
            result = result.replacingOccurrences(of: symbol, with: "")
        }
        return result.trimmingCharacters(in: .whitespaces.union(CharacterSet(charactersIn: "\u{202F}\u{00A0}")))
    }
}
