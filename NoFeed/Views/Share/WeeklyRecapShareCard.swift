//
//  WeeklyRecapShareCard.swift
//  NoFeed
//
//  The week's version of `SessionShareCard`.
//
//  Why a second card rather than a parameter on the first: a session card says
//  "25 min", which is a weak thing to post. A week says "4h 20m, and 23 times I
//  reached for something blocked and stopped" — the same acquisition loop
//  carrying an artifact worth someone's feed. The resisted count is the line no
//  other app on the reader's phone can print, so it is the one given the width.
//
//  Every constraint here is inherited from `SessionShareCard` and must not drift
//  from it — the two land in the same feed and have to read as one app:
//    · 360x450pt at 3x = 1080x1350, the 4:5 that survives Instagram feed,
//      Stories crop and a Messages preview without re-layout.
//    · Always night, with literal hex rather than adaptive colours, because
//      ImageRenderer resolves adaptive ones inconsistently.
//    · Neutral surface, one tone, no confetti. A card that shouts advertises a
//      different app than the one it opens.
//    · `EclipseMark` is the same geometry as the Home Screen icon, and only its
//      middle 47.7% is opaque — so it is sized large and padded tight.
//

import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

struct WeeklyRecapShareCard: View {
    let recap: WeeklyRecap
    let accentHex: String?

    static let size = CGSize(width: 360, height: 450)

    private let ground     = Color(hex: "07080A")
    private let groundLift = Color(hex: "12151F")
    private let ink        = Color(hex: "E7E8EC")

    private var tone: Color { ZTheme.tone(forHex: accentHex) }

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [groundLift, ground],
                center: UnitPoint(x: 0.5, y: 0.18),
                startRadius: 0,
                endRadius: Self.size.width * 0.95
            )
            .background(ground)

            VStack(spacing: 0) {
                EclipseMark(size: 108, tone: tone, core: Color(hex: "080A0E"))
                    .padding(.top, 30)

                Text("this week")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ink.opacity(0.45))
                    .padding(.top, 10)

                Text(recap.durationText)
                    .font(ZTheme.Font.numeral(64, weight: .regular))
                    .foregroundStyle(ink)
                    .padding(.top, 2)

                Text("of quiet")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ink.opacity(0.45))
                    .padding(.top, 2)

                Rectangle()
                    .fill(ink.opacity(0.10))
                    .frame(width: 44, height: 1)
                    .padding(.top, 20)

                // The card's actual argument. Given two lines of room and the
                // brighter ink because it is the only sentence here that is
                // about resisting something rather than doing something.
                Text(recap.resistedLine)
                    .font(ZTheme.Font.display(15, weight: .medium))
                    .foregroundStyle(ink.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 38)
                    .padding(.top, 18)

                Text(metaLine)
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ink.opacity(0.42))
                    .padding(.top, 14)

                Spacer(minLength: 0)

                HStack(spacing: 8) {
                    EclipseMark(size: 20, tone: tone, core: ground)
                    Text("NoFeed")
                        .font(ZTheme.Font.display(15, weight: .medium))
                        .foregroundStyle(ink.opacity(0.55))
                }
                .padding(.bottom, 28)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }

    /// "12 sessions", plus the comparison once there is a week to compare to.
    /// A first week says only what it did, because "0m more than the week
    /// before" is not a fact about anything.
    private var metaLine: String {
        let sessions = "\(recap.sessionCount) \(recap.sessionCount == 1 ? "session" : "sessions")"
        guard let comparison = recap.comparisonLine else { return sessions }
        return "\(sessions) · \(comparison.replacingOccurrences(of: ".", with: ""))"
    }
}

// MARK: - Rasterising

enum WeeklyRecapShareCardRenderer {
    static let scale: CGFloat = 3

    @MainActor
    static func image(for recap: WeeklyRecap, accentHex: String?) -> UIImage? {
        let renderer = ImageRenderer(
            content: WeeklyRecapShareCard(recap: recap, accentHex: accentHex)
        )
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

// MARK: - Handing it to the share sheet

/// PNG rather than `Image`'s default export, so the file that lands in Photos or
/// a DM has a real name instead of "Image.png".
struct SharedWeeklyRecapCard: Transferable {
    let image: UIImage
    let durationText: String

    /// "nofeed-week-4h-20m". Lowercased and hyphenated for a filename.
    var suggestedName: String {
        "nofeed-week-" + durationText.lowercased().replacingOccurrences(of: " ", with: "-")
    }

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { card in
            guard let data = card.image.pngData() else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        }
        .suggestedFileName { $0.suggestedName }
    }
}

#Preview {
    WeeklyRecapShareCard(
        recap: WeeklyRecap(
            weekStart: Date(),
            focusMinutes: 260,
            previousMinutes: 220,
            sessionCount: 12,
            attempts: 23,
            heldEveryTime: true,
            days: [.init(label: "Mon", minutes: 50), .init(label: "Tue", minutes: 100),
                   .init(label: "Wed", minutes: 25), .init(label: "Thu", minutes: 0),
                   .init(label: "Fri", minutes: 45), .init(label: "Sat", minutes: 25),
                   .init(label: "Sun", minutes: 15)],
            hadPreviousWeek: true
        ),
        accentHex: "7C93E8"
    )
}
