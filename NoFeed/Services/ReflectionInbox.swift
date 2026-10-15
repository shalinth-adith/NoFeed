//
//  ReflectionInbox.swift
//  NoFeed
//
//  Holds an answer given from the focus-end notification until the session it
//  belongs to exists.
//
//  The notification fires on the system's clock, but the FocusSession row is
//  only written when the app next runs `finishFocus` — on the next foreground
//  or restore. So an answer tapped on the Lock Screen usually arrives before
//  there is anything to attach it to. It is parked here, keyed by the session's
//  start time, and applied by whichever comes first: the record being created,
//  or the app's next activation finding it already there.
//

import Foundation

enum ReflectionInbox {
    private static let rawKey = "pendingReflectionRaw"
    private static let startedAtKey = "pendingReflectionStartedAt"

    /// How far apart two timestamps may be and still mean the same session.
    static let matchTolerance: TimeInterval = 1

    static func store(_ reflection: SessionReflection, startedAt: Date,
                      defaults: UserDefaults = AppGroup.defaults) {
        guard reflection != .none else { return }
        defaults.set(Int(reflection.rawValue), forKey: rawKey)
        defaults.set(startedAt.timeIntervalSince1970, forKey: startedAtKey)
    }

    /// Reads without clearing, so a caller can check the match before taking it.
    static func peek(defaults: UserDefaults = AppGroup.defaults) -> (reflection: SessionReflection, startedAt: Date)? {
        let raw = defaults.integer(forKey: rawKey)
        let epoch = defaults.double(forKey: startedAtKey)
        guard raw != 0, epoch > 0,
              let reflection = SessionReflection(rawValue: Int16(clamping: raw)),
              reflection != .none else { return nil }
        return (reflection, Date(timeIntervalSince1970: epoch))
    }

    /// Takes the pending answer if it belongs to a session that started at
    /// `startedAt`. Anything else is left alone for a later caller — and an
    /// answer whose session can no longer be found is dropped by `clear`.
    static func take(for startedAt: Date,
                     defaults: UserDefaults = AppGroup.defaults) -> SessionReflection? {
        guard let pending = peek(defaults: defaults),
              abs(pending.startedAt.timeIntervalSince(startedAt)) <= matchTolerance else { return nil }
        clear(defaults: defaults)
        return pending.reflection
    }

    static func clear(defaults: UserDefaults = AppGroup.defaults) {
        defaults.removeObject(forKey: rawKey)
        defaults.removeObject(forKey: startedAtKey)
    }
}
