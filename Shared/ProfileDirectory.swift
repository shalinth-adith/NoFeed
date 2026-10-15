//
//  ProfileDirectory.swift
//  NoFeed (shared: app + NoFeedWidget)
//
//  The profiles, as the widget sees them.
//
//  Profiles live in Core Data, and the widget extension does not carry the
//  model. It needs four facts per profile — id, name, tone, length — to offer
//  "Start Work" and to let the user pick which profile the widget starts. The
//  app writes those into the App Group every time the list changes; the widget
//  only ever reads. Same shape of contract as `ActiveSessionInfo`.
//

import Foundation

struct ProfileSummary: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let accentHex: String
    let focusMinutes: Int
}

enum ProfileDirectory {
    private static let key = "profileDirectory"
    /// Mirrors `ProfileStore.activeKey`; the store writes it, this reads it.
    private static let activeKey = "activeProfileID"

    static func save(_ profiles: [ProfileSummary], defaults: UserDefaults = AppGroup.defaults) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        defaults.set(data, forKey: key)
    }

    static func load(defaults: UserDefaults = AppGroup.defaults) -> [ProfileSummary] {
        guard let data = defaults.data(forKey: key),
              let profiles = try? JSONDecoder().decode([ProfileSummary].self, from: data) else { return [] }
        return profiles
    }

    static func profile(id: UUID, defaults: UserDefaults = AppGroup.defaults) -> ProfileSummary? {
        load(defaults: defaults).first { $0.id == id }
    }

    /// The profile the Focus tab has selected, falling back to the first — the
    /// same rule as `ProfileStore.activeProfile`.
    static func active(defaults: UserDefaults = AppGroup.defaults) -> ProfileSummary? {
        let all = load(defaults: defaults)
        if let raw = defaults.string(forKey: activeKey), let id = UUID(uuidString: raw),
           let match = all.first(where: { $0.id == id }) {
            return match
        }
        return all.first
    }
}
