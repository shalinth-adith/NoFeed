//
//  SessionShareCard.swift
//  NoFeed
//
//  The image a finished session can leave the app as.
//
//  NoFeed has streaks, badges, goals and weekly insights and — until this file —
//  no way for any of it to exist outside the app. That is the whole acquisition
//  loop missing: the card someone posts is the only advertising that costs
//  nothing per install.
//
//  Two rules it inherits from the Quiet spec, both of which cut against how
//  share cards normally look:
//
//  1. Neutral surface, one tone. No confetti, no rainbow gradient, no "🔥🔥🔥".
//     Screen 04 already refuses to celebrate loudly, and a card that shouts is
//     advertising a different app than the one it opens.
//  2. Only completed sessions get one. Screen 04b's entire argument is that a
//     session cut short is not a failure; handing that screen a "share this"
//     button turns it into one.
//
//  The mark on the card is `EclipseMark` — the same geometry as the Home Screen
//  icon, so a card seen in a feed and the icon seen in the App Store are
//  recognisably the same object.
//

import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

// MARK: - Card

/// Rendered at 360x450pt and rasterised at 3x for 1080x1350 — the 4:5 that
/// survives Instagram feed, Stories crop, and a Messages/WhatsApp preview
/// without being re-laid-out for each.
struct SessionShareCard: View {
    let summary: SessionSummary

    static let size = CGSize(width: 360, height: 450)

    // The card is always night. It is brand artwork rather than UI, so it does
    // not follow the reader's appearance — and pinning the values here keeps
    // ImageRenderer away from adaptive colours, which it resolves inconsistently.
    private let ground     = Color(hex: "07080A")
    private let groundLift = Color(hex: "12151F")
    private let ink        = Color(hex: "E7E8EC")

    private var tone: Color { ZTheme.tone(forHex: summary.accentHex) }

    var body: some View {
        ZStack {
            // Same lift as the icon tile: a soft rise behind the mark, centred
            // high, so the corona has something to sit in.
            RadialGradient(
                colors: [groundLift, ground],
                center: UnitPoint(x: 0.5, y: 0.18),
                startRadius: 0,
                endRadius: Self.size.width * 0.95
            )
            .background(ground)

            VStack(spacing: 0) {
                // Sized large and padded tight on purpose: only the middle
                // 47.7% of an EclipseMark is opaque, so the frame carries about
                // 25pt of invisible margin per side. Spacing it as though the
                // whole 120 were ink opens a hole under it.
                EclipseMark(size: 120, tone: tone, core: Color(hex: "080A0E"))
                    .padding(.top, 34)

                Text("focused for")
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ink.opacity(0.45))
                    .padding(.top, 12)

                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text("\(summary.completedMinutes)")
                        .font(ZTheme.Font.numeral(72, weight: .regular))
                        .foregroundStyle(ink)
                    Text("min")
                        .font(ZTheme.Font.body(21))
                        .foregroundStyle(ink.opacity(0.45))
                }
                .padding(.top, 2)

                Text("A calm, unbroken session.")
                    .font(ZTheme.Font.display(16, weight: .semibold))
                    .foregroundStyle(ink)
                    .padding(.top, 15)

                Rectangle()
                    .fill(ink.opacity(0.10))
                    .frame(width: 44, height: 1)
                    .padding(.top, 22)

                Text(metaLine)
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ink.opacity(0.42))
                    .padding(.top, 20)

                Spacer(minLength: 0)

                // The wordmark is the only thing on the card doing acquisition
                // work, so it is legible — but it is still the quietest element,
                // because a card that reads as an ad does not get posted.
                HStack(spacing: 8) {
                    EclipseMark(size: 20, tone: tone, core: ground)
                    Text("NoFeed")
                        .font(ZTheme.Font.display(15, weight: .medium))
                        .foregroundStyle(ink.opacity(0.55))
                }
                .padding(.bottom, 30)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .environment(\.colorScheme, .dark)
    }

    /// "Work" on its own, or "Work · 7-day streak" once a streak is worth a
    /// mention. A "1-day streak" is just today, and saying so out loud is the
    /// kind of padding the rest of the app avoids.
    var shareMetaLine: String { metaLine }

    private var metaLine: String {
        summary.streak > 1
            ? "\(summary.profileName) · \(summary.streak)-day streak"
            : summary.profileName
    }
}

// MARK: - Rasterising

enum SessionShareCardRenderer {
    /// 3x of 360x450 = 1080x1350.
    static let scale: CGFloat = 3

    @MainActor
    static func image(for summary: SessionSummary) -> UIImage? {
        let renderer = ImageRenderer(content: SessionShareCard(summary: summary))
        renderer.scale = scale
        renderer.isOpaque = true
        return renderer.uiImage
    }
}

// MARK: - Handing it to the share sheet

/// PNG rather than `Image`'s default export, so the file that lands in Photos
/// or a DM has a real name instead of "Image.png".
struct SharedSessionCard: Transferable {
    let image: UIImage
    let minutes: Int

    var suggestedName: String { "zen-ly-\(minutes)-min" }

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
    SessionShareCard(
        summary: SessionSummary(profileName: "Work",
                                accentHex: "7C93E8",
                                plannedMinutes: 50,
                                completedMinutes: 50,
                                completedSeconds: 3000,
                                wasCompleted: true,
                                endedEarly: false,
                                streak: 7)
    )
}
