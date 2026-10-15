//
//  ReadableColor.swift
//  NoFeed
//
//  The profile tones (periwinkle, amber, green, purple) are chosen as fills.
//  As text on the cream ground they sit near 2.5:1, and the accessibility audit
//  failed every place one was used as a label (review 2.3, follow-up).
//  `readable` keeps the hue and moves it toward ink — darker in light mode,
//  lighter in dark — until it clears 4.5:1 against the worst surface it can
//  sit on. Fills, rings and dots keep the raw tone; only text and icons that
//  carry meaning take this.
//

import SwiftUI
import UIKit

extension Color {
    /// This colour, adjusted per appearance to reach 4.5:1 as text.
    var readable: Color {
        let base = UIColor(self)
        return Color(uiColor: UIColor { traits in
            let resolved = base.resolvedColor(with: traits)
            let dark = traits.userInterfaceStyle == .dark
            // Worst case per mode: a white card in light, the raised dark
            // card (#16171C) in dark.
            let ground = dark ? UIColor(red: 0x16/255, green: 0x17/255, blue: 0x1C/255, alpha: 1)
                              : UIColor.white
            // 5:1 rather than 4.5:1 — the audit renders small text with antialiasing
            // and "nearly passed" a tone tuned to the exact threshold.
            return resolved.adjusted(toContrast: 5.0, against: ground, towardBlack: !dark)
        })
    }
}

extension UIColor {
    /// Mixes toward black or white in small steps until `ratio` is reached.
    func adjusted(toContrast ratio: CGFloat, against ground: UIColor, towardBlack: Bool) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let target: CGFloat = towardBlack ? 0 : 1
        var t: CGFloat = 0
        while t <= 1 {
            let candidate = UIColor(red: r + (target - r) * t,
                                    green: g + (target - g) * t,
                                    blue: b + (target - b) * t,
                                    alpha: 1)
            if candidate.contrast(with: ground) >= ratio { return candidate }
            t += 0.04
        }
        return towardBlack ? .black : .white
    }

    func contrast(with other: UIColor) -> CGFloat {
        let l1 = relativeLuminance, l2 = other.relativeLuminance
        return (max(l1, l2) + 0.05) / (min(l1, l2) + 0.05)
    }

    var relativeLuminance: CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        func channel(_ c: CGFloat) -> CGFloat {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)
    }
}
