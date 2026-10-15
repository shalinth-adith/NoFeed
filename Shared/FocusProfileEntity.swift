//
//  FocusProfileEntity.swift
//  NoFeed (shared: app + NoFeedWidget)
//
//  A focus profile as an App Intents entity, so Shortcuts, Siri and the widget
//  configuration sheet can offer "Work / Study / Gym / Sleep" as a picker
//  instead of a free-text name. Backed by `ProfileDirectory`, which both the
//  app and the widget process can read.
//

import AppIntents

struct FocusProfileEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Focus Profile"
    static var defaultQuery = FocusProfileQuery()

    let id: UUID
    let name: String
    let accentHex: String
    let focusMinutes: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(focusMinutes) min")
    }

    init(_ summary: ProfileSummary) {
        id = summary.id
        name = summary.name
        accentHex = summary.accentHex
        focusMinutes = summary.focusMinutes
    }

    var summary: ProfileSummary {
        ProfileSummary(id: id, name: name, accentHex: accentHex, focusMinutes: focusMinutes)
    }
}

struct FocusProfileQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [FocusProfileEntity] {
        ProfileDirectory.load()
            .filter { identifiers.contains($0.id) }
            .map(FocusProfileEntity.init)
    }

    func suggestedEntities() async throws -> [FocusProfileEntity] {
        ProfileDirectory.load().map(FocusProfileEntity.init)
    }

    /// The Focus tab's current profile, so a freshly added widget starts the
    /// same thing the app would.
    func defaultResult() async -> FocusProfileEntity? {
        ProfileDirectory.active().map(FocusProfileEntity.init)
    }
}
