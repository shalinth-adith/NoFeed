//
//  WeeklyRecap.swift
//  NoFeed
//
//  The week, said once.
//
//  Everything else the app says is about a moment: this session is running, this
//  app is behind a door, this break is over. Nothing steps back. The recap is the
//  one place the week gets summed up, and the only place `DistractionLog` — which
//  has been counting every reach for a blocked app since day one — is ever read
//  back to the person it is about.
//
//  Deliberately a plain value type with no Core Data and no services in it. Every
//  sentence below is a pure function of six numbers, so the wording can be tested
//  without a store, a simulator, or a week of real history. `AnalyticsService`
//  gathers the numbers; this decides what they mean.
//
//  Voice rules inherited from the Quiet spec, same ones the share card follows:
//  no exclamation marks, no emoji, no confetti. A recap that shouts is advertising
//  a different app than the one it opens. It also never scolds — a lighter week is
//  reported as a lighter week, not as a failure.
//

import Foundation

struct WeeklyRecap: Equatable {

    /// One day of the week being reported. `label` is already localised ("Mon").
    struct Day: Equatable {
        let label: String
        let minutes: Int
    }

    /// Midnight on the first day of the week this recap covers.
    let weekStart: Date
    /// Completed focus minutes in that week.
    let focusMinutes: Int
    /// Completed focus minutes in the week before it.
    let previousMinutes: Int
    /// Completed focus sessions in that week.
    let sessionCount: Int
    /// Times a blocked app or site was reached for — the shield appearing is the
    /// event, so this counts being stopped, not giving in.
    let attempts: Int
    /// True when no session that week was ended early. Gates the difference
    /// between "stopped every time" and "stopped almost every time"; claiming the
    /// first when a session was abandoned would be a lie, and a recap that
    /// flatters is worth less than one that is right.
    let heldEveryTime: Bool
    /// Seven days, first day of the week first. Drives the small chart.
    let days: [Day]
    /// False in the very first week, when there is nothing to compare against and
    /// a "0 minutes less than last week" would be noise rather than information.
    let hadPreviousWeek: Bool

    // MARK: - Shape

    /// A week with nothing in it. The notification is suppressed on these: an
    /// unprompted "you focused for 0 minutes" is a guilt notification, and this
    /// app does not send those. The screen still renders if opened by hand.
    var isEmpty: Bool { sessionCount == 0 && focusMinutes == 0 }

    var deltaMinutes: Int { focusMinutes - previousMinutes }

    /// Within this many minutes of last week counts as level rather than up or
    /// down. Without a band, a four-minute swing across five hours reads as
    /// progress, which is the kind of padding the rest of the app avoids.
    private var isLevel: Bool { abs(deltaMinutes) <= 5 }

    // MARK: - Sentences

    /// "4h 20m", "45m", "0m". Compact because it sits under a numeral, not in prose.
    var durationText: String { Self.duration(focusMinutes) }

    /// The comparison against last week, or nil when there is nothing to compare.
    var comparisonLine: String? {
        guard hadPreviousWeek else { return nil }
        if isLevel { return "About the same as the week before." }
        let magnitude = Self.duration(abs(deltaMinutes))
        return deltaMinutes > 0
            ? "\(magnitude) more than the week before."
            : "\(magnitude) less than the week before."
    }

    /// The line the whole recap exists to deliver. `DistractionLog` records an
    /// attempt when the shield is *shown* — so every one of these is a moment the
    /// door held, which is the opposite of what a raw "distraction count" sounds
    /// like and is why it is phrased as a win.
    var resistedLine: String {
        guard attempts > 0 else { return "Nothing pulled at you this week." }

        let reach = attempts == 1
            ? "You reached for a blocked app once"
            : "You reached for a blocked app \(attempts) times"

        return heldEveryTime
            ? "\(reach), and stopped every time."
            : "\(reach), and stopped almost every time."
    }

    /// One line on what the week was. Never scolds, never shouts.
    var motivation: String {
        if isEmpty {
            return "A week away from it. Next week is open."
        }
        if !hadPreviousWeek {
            return "Your first week of this. The rest builds on it."
        }
        if isLevel {
            return "Level with last week. Steady is the harder thing to do."
        }
        return deltaMinutes > 0
            ? "More quiet than last week. It is adding up."
            : "A lighter week than the last. It still counts."
    }

    /// A forward-looking nudge drawn from the shape of the week, or nil when the
    /// week is too uniform to say anything true about it.
    ///
    /// Named days rather than generic advice: "Thursday was your quietest" is
    /// something only this app can tell you, and is the reason to open the screen.
    var suggestion: String? {
        if isEmpty {
            return "Fifteen minutes is enough to start with. Pick one day next week."
        }
        guard days.contains(where: { $0.minutes > 0 }) else { return nil }

        // A day with nothing in it is the cheapest win available next week.
        if let quietest = days.first(where: { $0.minutes == 0 }) {
            return "\(quietest.label) had none. One short session there would even out the week."
        }

        // Otherwise point at what already worked and ask for it again.
        if let best = days.max(by: { $0.minutes < $1.minutes }), best.minutes > 0 {
            return "\(best.label) was your strongest day, at \(Self.duration(best.minutes)). Worth repeating."
        }
        return nil
    }

    /// The notification body — the recap compressed to one sentence that has to
    /// survive a Lock Screen. Leads with the number, because that is what makes
    /// someone open it.
    var notificationBody: String {
        var parts = ["\(durationText) of quiet across \(sessionCount) \(sessionCount == 1 ? "session" : "sessions")."]
        if attempts > 0 { parts.append(resistedLine) }
        return parts.joined(separator: " ")
    }

    // MARK: - Formatting

    /// "4h 20m" / "4h" / "45m". Drops a zero minute component so whole hours read
    /// as whole hours.
    static func duration(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes)m" }
        let hours = minutes / 60
        let rest = minutes % 60
        return rest == 0 ? "\(hours)h" : "\(hours)h \(rest)m"
    }
}
