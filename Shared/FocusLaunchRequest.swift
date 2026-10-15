//
//  FocusLaunchRequest.swift
//  NoFeed (shared: app + NoFeedWidget)
//
//  Handoff for starting a focus session from outside the app — App Intent,
//  Control Center, Siri, or a tap on the widget. The outside party records the
//  request (optionally naming a profile) and opens the app; the app consumes
//  it on becoming active and starts the session.
//
//  Two doors in, one flag: intents call `request(profileID:)` directly, and the
//  widget's tap arrives as a `nofeed://start?profile=…` URL that the app turns
//  into the same request. Widgets cannot run an intent that opens the app, so
//  the URL is the only way a Home Screen tap can land here.
//

import Foundation

enum FocusLaunchRequest {
    private static let key = "pendingFocusStart"
    private static let profileKey = "pendingFocusProfileID"

    /// Which profile the request named, if any. Nil means the active one.
    struct Pending: Equatable {
        let profileID: UUID?
    }

    static func request(profileID: UUID? = nil, defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(true, forKey: key)
        if let profileID {
            defaults.set(profileID.uuidString, forKey: profileKey)
        } else {
            defaults.removeObject(forKey: profileKey)
        }
    }

    /// Returns the request once, then clears it.
    static func consume(defaults: UserDefaults = AppGroup.defaults) -> Pending? {
        guard defaults.bool(forKey: key) else { return nil }
        defaults.set(false, forKey: key)
        let raw = defaults.string(forKey: profileKey)
        defaults.removeObject(forKey: profileKey)
        return Pending(profileID: raw.flatMap(UUID.init(uuidString:)))
    }

    // MARK: - URL form

    static let scheme = "nofeed"
    static let host = "start"

    /// `nofeed://start` or `nofeed://start?profile=<uuid>`.
    static func url(profileID: UUID?) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        if let profileID {
            components.queryItems = [URLQueryItem(name: "profile", value: profileID.uuidString)]
        }
        return components.url ?? URL(string: "\(scheme)://\(host)")!
    }

    /// The request a URL carries, or nil when the URL is not a start link.
    static func pending(from url: URL) -> Pending? {
        guard url.scheme?.lowercased() == scheme,
              url.host?.lowercased() == host,
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let raw = components.queryItems?.first { $0.name == "profile" }?.value
        return Pending(profileID: raw.flatMap(UUID.init(uuidString:)))
    }
}
