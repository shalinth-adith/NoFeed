//
//  NoFeedWidget.swift
//  NoFeedWidget
//
//  Home-screen widget showing a focus stat from the App-Group StatsSnapshot.
//  Uses AppIntentConfiguration so the user picks which metric to display
//  (WidgetKit + AppIntents).
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
    static var title: LocalizedStringResource = "NoFeed Stat"
    static var description = IntentDescription("Choose which focus stat to show.")

    @Parameter(title: "Metric", default: .streak)
    var metric: WidgetMetric
}

// MARK: - Timeline

struct NoFeedEntry: TimelineEntry {
    let date: Date
    let snapshot: StatsSnapshot
    let metric: WidgetMetric
}

struct NoFeedProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NoFeedEntry {
        NoFeedEntry(date: .now, snapshot: .empty, metric: .streak)
    }

    func snapshot(for configuration: NoFeedWidgetConfiguration, in context: Context) async -> NoFeedEntry {
        NoFeedEntry(date: .now, snapshot: StatsStore.load(), metric: configuration.metric)
    }

    func timeline(for configuration: NoFeedWidgetConfiguration, in context: Context) async -> Timeline<NoFeedEntry> {
        let entry = NoFeedEntry(date: .now, snapshot: StatsStore.load(), metric: configuration.metric)
        return Timeline(entries: [entry], policy: .after(.now.addingTimeInterval(1800)))
    }
}

// MARK: - View

struct NoFeedWidgetEntryView: View {
    let entry: NoFeedEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("NoFeed", systemImage: icon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.tint)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .containerBackground(.fill.tertiary, for: .widget)
    }

    private var icon: String {
        switch entry.metric {
        case .streak: return "flame.fill"
        case .minutes: return "clock.fill"
        case .attempts: return "shield.fill"
        }
    }

    private var value: String {
        switch entry.metric {
        case .streak: return "\(entry.snapshot.streak)"
        case .minutes: return "\(entry.snapshot.todayMinutes)"
        case .attempts: return "\(entry.snapshot.todayAttempts)"
        }
    }

    private var label: String {
        switch entry.metric {
        case .streak: return "day streak"
        case .minutes: return "min focused today"
        case .attempts: return "distractions blocked"
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
        .description("Your focus at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
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
