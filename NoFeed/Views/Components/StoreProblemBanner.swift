//
//  StoreProblemBanner.swift
//  NoFeed
//
//  Shown at the top of every screen while `StoreHealth` reports a problem.
//  Says what is lost and what to do; never blocks the app, because a focus
//  session that can't be saved can still be useful.
//

import SwiftUI

struct StoreProblemBanner: View {
    let problem: StoreHealth.Problem
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ZTheme.Palette.alert.readable)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(ZTheme.Font.body(14, weight: .semibold))
                    .foregroundStyle(ZTheme.Palette.textPrimary)
                Text(message)
                    .font(ZTheme.Font.body(13))
                    .foregroundStyle(ZTheme.Palette.text(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if case .saveFailed = problem {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(ZTheme.Palette.text(0.72))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: ZTheme.Radius.chip, style: .continuous)
                .fill(ZTheme.Palette.matte)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ZTheme.Radius.chip, style: .continuous)
                .strokeBorder(ZTheme.Palette.alert.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("store-problem-banner")
    }

    private var title: String {
        switch problem {
        case .unavailable: return String(localized: "NoFeed can\u{2019}t save right now")
        case .saveFailed: return String(localized: "A change wasn\u{2019}t saved")
        }
    }

    private var message: String {
        switch problem {
        case .unavailable:
            return String(localized: "Its data couldn\u{2019}t be opened, so sessions and changes won\u{2019}t be kept until it restarts. Close NoFeed from the app switcher and open it again. If this keeps happening, use Settings \u{203A} Send feedback.")
        case .saveFailed:
            return String(localized: "Your last change may not have been kept. Try it again; if it keeps failing, restart NoFeed.")
        }
    }
}
