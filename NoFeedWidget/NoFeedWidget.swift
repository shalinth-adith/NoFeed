//
//  NoFeedWidget.swift
//  NoFeedWidget
//
//  The Home Screen and Lock Screen widget.
//
//  Idle, it shows one stat from the App Group `StatsSnapshot` — the user picks
//  which — and a "Start <profile>" pill. While a session runs it becomes a
//  countdown in the profile's tone, driven by `ActiveSessionInfo` and a
//  `Text(timerInterval:)` so it ticks without a timeline entry per second.
//
//  The pill is a `Link`, not a `Button(intent:)`. An interactive widget runs
//  its intent in the background and cannot open the app, and starting a focus
//  session needs the app: Screen Time, the ticker, the Live Activity. So the
//  tap sends `nofeed://start?profile=…` and `NoFeedApp` does the rest.
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration intent

enum WidgetMetric: String, AppEnum {
    case streak
    case minutes
    case attempts

    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Metric" }

    static var caseDisplayRepresentations: [WidgetMetric: DisplayRepresentation] {
        [
            .streak: "Day streak",
            .minutes: "Focus minutes today",
            .attempts: "Distractions blocked"
        ]
    }
}

struct NoFeedWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "NoFeed"
    static var description = IntentDescription("Choose which stat to show, and which profile the Start button runs.")

    @Parameter(title: "Metric", default: .streak)
    var metric: WidgetMetric

    /// Nil means whatever the Focus tab has selected at the time.
    @Parameter(title: "Start profile")
    var profile: FocusProfileEntity?
}

// MARK: - Timeline

struct NoFeedEntry: TimelineEntry {
    enum State {
        case idle(StatsSnapshot)
        case active(profileName: String, endsAt: Date, accentHex: String?)
        /// The moment a session ends while the app is suspended. The snapshot
        /// has not been rewritten yet, so this says so instead of showing
        /// numbers that are an hour old.
        case done
    }

    let date: Date
    let state: State
    let metric: WidgetMetric
    /// What the Start pill runs. Resolved at timeline time, not at tap time.
    let startProfile: ProfileSummary?
}

struct NoFeedProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NoFeedEntry {
        NoFeedEntry(date: .now, state: .idle(.empty), metric: .streak,
                    startProfile: ProfileSummary(id: UUID(), name: "Work", accentHex: "7C93E8", focusMinutes: 25))
    }

    func snapshot(for configuration: NoFeedWidgetConfiguration, in context: Context) async -> NoFeedEntry {
        NoFeedEntry(date: .now, state: .idle(StatsStore.load()), metric: configuration.metric,
                    startProfile: startProfile(for: configuration))
    }

    func timeline(for configuration: NoFeedWidgetConfiguration, in context: Context) async -> Timeline<NoFeedEntry> {
        let start = startProfile(for: configuration)

        if let endsAt = ActiveSessionInfo.endsAt {
            let running = NoFeedEntry(
                date: .now,
                state: .active(profileName: ActiveSessionInfo.profileName ?? "Focus",
                               endsAt: endsAt,
                               accentHex: ActiveSessionInfo.accentHex),
                metric: configuration.metric,
                startProfile: start)
            let finished = NoFeedEntry(date: endsAt, state: .done, metric: configuration.metric,
                                       startProfile: start)
            // The app rewrites the snapshot and reloads this timeline when it
            // records the session; until then `.done` stands in.
            return Timeline(entries: [running, finished], policy: .after(endsAt.addingTimeInterval(60)))
        }

        let entry = NoFeedEntry(date: .now, state: .idle(StatsStore.load()), metric: configuration.metric,
                                startProfile: start)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(1800)))
    }

    private func startProfile(for configuration: NoFeedWidgetConfiguration) -> ProfileSummary? {
        configuration.profile?.summary ?? ProfileDirectory.active()
    }
}

// MARK: - View

struct NoFeedWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NoFeedEntry

    private let ink = Color(hex: "0A0B0E")

    var body: some View {
        switch family {
        case .accessoryCircular:
            circular
                .containerBackground(for: .widget) { AccessoryWidgetBackground() }
        case .accessoryRectangular:
            rectangular
                .containerBackground(for: .widget) { Color.clear }
        case .accessoryInline:
            inline
                .containerBackground(for: .widget) { Color.clear }
        default:
            system
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }

    // MARK: Home Screen

    @ViewBuilder
    private var system: some View {
        switch entry.state {
        case .idle(let snapshot):
            if family == .systemMedium {
                HStack(alignment: .bottom, spacing: 16) {
                    stat(snapshot)
                    Spacer(minLength: 0)
                    startPill
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    stat(snapshot)
                    startPill
                }
            }
        case .active(let profileName, let endsAt, let accentHex):
            countdown(profileName: profileName, endsAt: endsAt, tone: tone(accentHex))
        case .done:
            VStack(alignment: .leading, spacing: 6) {
                Label("NoFeed", systemImage: "circle.circle")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tint)
                Spacer(minLength: 0)
                Text("Session done")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                Text("Open to review")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private func stat(_ snapshot: StatsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("NoFeed", systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tint)
            Spacer(minLength: 0)
            Text(value(snapshot))
                .font(.system(size: family == .systemSmall ? 34 : 40, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value(snapshot)) \(label)")
    }

    /// "Start Work", in the profile's tone. Absent when there is no profile to
    /// start, which only happens before the app has ever been opened.
    @ViewBuilder
    private var startPill: some View {
        if let profile = entry.startProfile {
            Link(destination: FocusLaunchRequest.url(profileID: profile.id)) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 10, weight: .bold))
                    Text("Start \(profile.name)")
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(ink)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .frame(maxWidth: family == .systemSmall ? .infinity : nil)
                .background(Capsule().fill(tone(profile.accentHex)))
            }
            .accessibilityLabel("Start a \(profile.focusMinutes) minute \(profile.name) session")
        }
    }

    private func countdown(profileName: String, endsAt: Date, tone: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("FOCUSING · \(profileName.uppercased())")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.6)
                .foregroundStyle(tone)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(timerInterval: Date.now...endsAt, countsDown: true)
                .font(.system(size: family == .systemSmall ? 36 : 44, weight: .light, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text("remaining")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(profileName) session running")
    }

    // MARK: Lock Screen

    @ViewBuilder
    private var circular: some View {
        switch entry.state {
        case .active(_, let endsAt, _):
            Text(timerInterval: Date.now...endsAt, countsDown: true)
                .font(.system(size: 14, weight: .medium))
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .widgetAccentable()
                .widgetURL(FocusLaunchRequest.url(profileID: nil))
        case .idle(let snapshot):
            VStack(spacing: 0) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .widgetAccentable()
                Text(value(snapshot))
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(value(snapshot)) \(label)")
            .widgetURL(startURL)
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 18, weight: .semibold))
                .widgetAccentable()
                .accessibilityLabel("Session done")
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        switch entry.state {
        case .active(let profileName, let endsAt, _):
            VStack(alignment: .leading, spacing: 2) {
                Text(profileName)
                    .font(.system(size: 13, weight: .semibold))
                    .widgetAccentable()
                Text(timerInterval: Date.now...endsAt, countsDown: true)
                    .font(.system(size: 22, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(profileName) session running")
        case .idle(let snapshot):
            VStack(alignment: .leading, spacing: 2) {
                Label("NoFeed", systemImage: "circle.circle")
                    .font(.system(size: 13, weight: .semibold))
                    .widgetAccentable()
                Text("\(snapshot.todayMinutes) min today · \(snapshot.streak)-day streak")
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                if let profile = entry.startProfile {
                    Text("Tap to start \(profile.name)")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .widgetURL(startURL)
        case .done:
            VStack(alignment: .leading, spacing: 2) {
                Text("Session done")
                    .font(.system(size: 13, weight: .semibold))
                    .widgetAccentable()
                Text("Open to review")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var inline: some View {
        switch entry.state {
        case .active(let profileName, let endsAt, _):
            (Text(profileName + " · ") + Text(timerInterval: Date.now...endsAt, countsDown: true))
        case .idle(let snapshot):
            Text("NoFeed · \(snapshot.streak)-day streak")
                .widgetURL(startURL)
        case .done:
            Text("NoFeed · session done")
        }
    }

    // MARK: Pieces

    private var startURL: URL { FocusLaunchRequest.url(profileID: entry.startProfile?.id) }

    private func tone(_ hex: String?) -> Color {
        Color(hex: hex ?? "7C93E8")
    }

    private var icon: String {
        switch entry.metric {
        case .streak: return "flame.fill"
        case .minutes: return "clock.fill"
        case .attempts: return "shield.fill"
        }
    }

    private func value(_ snapshot: StatsSnapshot) -> String {
        switch entry.metric {
        case .streak: return "\(snapshot.streak)"
        case .minutes: return "\(snapshot.todayMinutes)"
        case .attempts: return "\(snapshot.todayAttempts)"
        }
    }

    private var label: String {
        switch entry.metric {
        case .streak: return String(localized: "day streak")
        case .minutes: return String(localized: "min focused today")
        case .attempts: return String(localized: "distractions blocked")
        }
    }
}

// MARK: - Widget

struct NoFeedWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: "NoFeedWidget",
            intent: NoFeedWidgetConfiguration.self,
            provider: NoFeedProvider()
        ) { entry in
            NoFeedWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NoFeed")
        .description("Your focus at a glance, and a button to start.")
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct NoFeedWidgetBundle: WidgetBundle {
    var body: some Widget {
        NoFeedWidget()
        FocusLiveActivity()
        if #available(iOS 18.0, *) {
            StartFocusControl()
        }
    }
}
