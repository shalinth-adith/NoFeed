//
//  WidgetRefresh.swift
//  NoFeed
//
//  The one place the Home Screen widget is told something changed.
//
//  Before this, the snapshot the widget reads was written only when Insights
//  was opened, so a widget could show yesterday's streak for a week. Now every
//  session start, pause, resume and end rewrites the snapshot and asks
//  WidgetKit to rebuild the timeline, which is also what makes the widget's
//  countdown appear and disappear with the session.
//

import WidgetKit

enum WidgetRefresh {
    /// Must match the `kind` in `NoFeedWidget`.
    static let kind = "NoFeedWidget"

    @MainActor
    static func sessionChanged(history: SessionHistory) {
        history.writeStatsSnapshot()
        WidgetCenter.shared.reloadTimelines(ofKind: kind)
    }
}
