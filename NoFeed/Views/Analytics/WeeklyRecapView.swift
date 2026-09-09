//
//  WeeklyRecapView.swift
//  NoFeed
//
//  Where the weekly recap notification lands, and what "Your week" on Insights
//  opens.
//
//  Built to the same rules as Insights rather than as a card stack: flat rows on
//  the quiet surface, hairline separators, neutral throughout with the profile's
//  tone as the single highlight. A recap screen is exactly the place a design
//  reaches for gradients and trophies, and doing that here would contradict the
//  completion screen it sits next to.
//
//  Order is deliberate. The duration is the headline because it is what makes
//  someone open the notification, but the resisted line is set larger than the
//  supporting copy because it is the sentence with the actual argument in it —
//  the number no other app on the phone can tell them.
//
//  The recap is recomputed from Core Data in `onAppear` rather than carried in
//  from the notification: a banner armed on Friday can quote Friday's totals, and
//  the screen it opens should still be right.
//

import SwiftUI

struct WeeklyRecapView: View {
    @Environment(AnalyticsService.self) private var analytics
    @Environment(ProfileStore.self) private var profiles
    @Environment(\.dismiss) private var dismiss

    @State private var recap: WeeklyRecap?
    /// Rendered on appear rather than on tap — `ImageRenderer` is synchronous,
    /// and doing it on tap puts a hitch between the tap and the share sheet.
    @State private var shareCard: SharedWeeklyRecapCard?

    private var tone: Color { ZTheme.tone(forHex: profiles.activeProfile?.accentHex) }

    var body: some View {
        NavigationStack {
            ZStack {
                NoFeedBackground()

                if let recap {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            header(recap)
                            chart(recap)
                                .padding(.top, 34)
                            hairline(strong: true)
                                .padding(.top, 30)
                            resisted(recap)
                            hairline()
                                .padding(.top, 26)
                            if let suggestion = recap.suggestion {
                                nextWeek(suggestion)
                            }
                            Spacer(minLength: 30)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 8)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { shareButton }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .font(ZTheme.Font.body(15))
                        .foregroundStyle(ZTheme.Palette.text(0.55))
                        .accessibilityIdentifier("recap-done")
                }
            }
        }
        .onAppear(perform: load)
    }

    private func load() {
        let built = analytics.weeklyRecap()
        recap = built
        if let image = WeeklyRecapShareCardRenderer.image(
            for: built, accentHex: profiles.activeProfile?.accentHex
        ) {
            shareCard = SharedWeeklyRecapCard(image: image, durationText: built.durationText)
        }
    }

    // MARK: - Header

    private func header(_ recap: WeeklyRecap) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Your week")
                .font(ZTheme.Font.display(28, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)

            Text(weekRange(recap))
                .font(ZTheme.Font.body(13))
                .foregroundStyle(ZTheme.Palette.text(0.30))
                .padding(.top, 4)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(recap.durationText)
                    .font(ZTheme.Font.numeral(56, weight: .regular))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text("of quiet")
                    .font(ZTheme.Font.body(17))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
            }
            .padding(.top, 24)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(recap.durationText) of quiet this week")

            if let comparison = recap.comparisonLine {
                Text(comparison)
                    .font(ZTheme.Font.body(14))
                    .foregroundStyle(ZTheme.Palette.text(0.55))
                    .padding(.top, 6)
            }

            Text("\(recap.sessionCount) \(recap.sessionCount == 1 ? "session" : "sessions")")
                .font(ZTheme.Font.body(14))
                .foregroundStyle(ZTheme.Palette.text(0.30))
                .padding(.top, 2)
        }
    }

    /// "13–19 Jan". A range rather than "this week" so a recap screenshotted or
    /// reopened later still says which week it was about.
    private func weekRange(_ recap: WeeklyRecap) -> String {
        let calendar = Calendar.current
        let end = calendar.date(byAdding: .day, value: 6, to: recap.weekStart) ?? recap.weekStart
        let day = DateFormatter(); day.dateFormat = "d"
        let dayMonth = DateFormatter(); dayMonth.dateFormat = "d MMM"
        return "\(day.string(from: recap.weekStart))–\(dayMonth.string(from: end))"
    }

    // MARK: - Chart

    /// The same seven bars as Insights, with one difference: Insights highlights
    /// *today*, which is meaningless on a week that has finished. This highlights
    /// the strongest day instead — the one the suggestion underneath refers to.
    private func chart(_ recap: WeeklyRecap) -> some View {
        let maxMinutes = max(1, recap.days.map(\.minutes).max() ?? 1)
        let best = recap.days.max(by: { $0.minutes < $1.minutes })?.label
        return HStack(alignment: .bottom, spacing: 10) {
            ForEach(Array(recap.days.enumerated()), id: \.offset) { _, day in
                let isBest = day.label == best && day.minutes > 0
                VStack(spacing: 10) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isBest ? tone : ZTheme.Palette.glassFill)
                        .frame(width: 20,
                               height: day.minutes == 0
                                   ? 4
                                   : max(8, CGFloat(day.minutes) / CGFloat(maxMinutes) * 92))
                    Text(String(day.label.prefix(1)))
                        .font(ZTheme.Font.body(11))
                        .foregroundStyle(isBest ? ZTheme.Palette.textPrimary
                                                : ZTheme.Palette.text(0.30))
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(day.label): \(day.minutes) minutes")
            }
        }
        .frame(height: 126)
    }

    // MARK: - The argument

    private func resisted(_ recap: WeeklyRecap) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(recap.resistedLine)
                .font(ZTheme.Font.display(19, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            Text(recap.motivation)
                .font(ZTheme.Font.body(14))
                .foregroundStyle(ZTheme.Palette.text(0.55))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 26)
        .accessibilityElement(children: .combine)
    }

    private func nextWeek(_ suggestion: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NEXT WEEK")
                .font(ZTheme.Font.body(11))
                .tracking(1.8)
                .foregroundStyle(ZTheme.Palette.text(0.30))
            Text(suggestion)
                .font(ZTheme.Font.body(15))
                .foregroundStyle(ZTheme.Palette.text(0.75))
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 24)
        .accessibilityElement(children: .combine)
    }

    // MARK: - Share

    /// Absent until the card has rendered, so the sheet can never open empty —
    /// the same rule the session summary's share button follows.
    @ViewBuilder
    private var shareButton: some View {
        if let card = shareCard, let recap {
            ShareLink(
                item: card,
                preview: SharePreview("\(recap.durationText) of focus this week",
                                      image: Image(uiImage: card.image))
            ) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 17))
                    .foregroundStyle(ZTheme.Palette.text(0.40))
            }
            .accessibilityLabel("Share this week")
            .accessibilityIdentifier("recap-share")
        }
    }

    private func hairline(strong: Bool = false) -> some View {
        Rectangle()
            .fill(strong ? ZTheme.Palette.glassStroke : ZTheme.Palette.glassStroke.opacity(0.6))
            .frame(height: 1)
    }
}
