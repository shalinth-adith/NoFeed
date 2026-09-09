//
//  EclipseMark.swift
//  NoFeed
//
//  The app icon, as a view.
//
//  The icon is a disc sitting exactly over a ring of light — nothing removed,
//  only covered, and it comes back on its own. That is the same argument the
//  block screen makes, which is why the mark is worth having in-app rather than
//  only on the Home Screen: anywhere it appears, it is saying the thing the
//  product is for.
//
//  Geometry is lifted from `design/app-icon/icon-default.html` verbatim and
//  expressed as fractions of the tile, so this and the shipped 1024 raster can
//  never drift. Changing a number here without changing the icon source is a
//  bug in both directions.
//

import SwiftUI

struct EclipseMark: View {
    /// Tile edge. Every other dimension derives from this.
    let size: CGFloat
    /// The lit ring. Defaults to the Work periwinkle; per-profile screens pass
    /// the active profile's tone.
    var tone: Color = ZTheme.Palette.tone
    /// What the disc is filled with. It reads as "the light is covered", not
    /// "there is a hole", so it wants to match whatever sits behind the mark.
    var core: Color = Color(hex: "080A0E")

    // Fractions of the tile, from the icon source at its native 264pt:
    //   corona 198.8 · ring 125.9 · disc 119.6
    private var coronaSize: CGFloat { size * 0.75303 }
    private var ringSize:   CGFloat { size * 0.47689 }
    private var discSize:   CGFloat { size * 0.45303 }

    var body: some View {
        ZStack {
            // The corona is painted, not lit by the system — see the icon README.
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: tone.opacity(0.62), location: 0.34),
                            .init(color: tone.opacity(0.10), location: 0.62),
                            .init(color: tone.opacity(0),    location: 0.76),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: coronaSize / 2
                    )
                )
                .frame(width: coronaSize, height: coronaSize)

            Circle()
                .fill(tone)
                .frame(width: ringSize, height: ringSize)
                // CSS blur is roughly twice SwiftUI's shadow radius, so the
                // icon's 29px blur lands at ~0.055 of the tile.
                .shadow(color: tone.opacity(0.5), radius: size * 0.055)

            Circle()
                .fill(core)
                .frame(width: discSize, height: discSize)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    ZStack {
        Color(hex: "07080A")
        VStack(spacing: 30) {
            EclipseMark(size: 120)
            EclipseMark(size: 56, tone: ZTheme.Palette.teal)
            EclipseMark(size: 22)
        }
    }
    .ignoresSafeArea()
}
